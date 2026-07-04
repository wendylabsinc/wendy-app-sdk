#if canImport(Glibc)
    import Glibc
#elseif canImport(Darwin)
    import Darwin
#endif
import Foundation

/// Errors starting a `MeshFanout` listener.
public enum MeshFanoutError: Error, CustomStringConvertible {
    case listenFailed(step: String, errno: Int32)
    public var description: String {
        switch self {
        case .listenFailed(let step, let errno):
            return "MeshFanout: \(step) failed (errno \(errno))"
        }
    }
}

/// A symmetric mesh peer: listens for incoming single-frame messages from
/// peers, and can broadcast a message to every configured peer. Every demo
/// built on this (MeshBeacon, MeshCounter) runs the identical listen+
/// broadcast pair — only the message type/payload and what `onMessage` does
/// with it differ.
///
/// Both directions are "one frame per connection, then close" — there is no
/// persistent peer-to-peer session. This keeps the demo apps' failure modes
/// simple: a peer that's unreachable or slow only ever affects the one
/// broadcast attempt to it, never blocks the listener or other peers.
public final class MeshFanout: @unchecked Sendable {
    public let peers: [String]
    private let listenPort: UInt16
    private let onMessage: (UInt8, [UInt8]) -> Void

    /// - Parameters:
    ///   - peers: mesh hostnames to broadcast to (see `parseMeshPeers`).
    ///   - listenPort: the port this device listens on AND the port peers
    ///     are dialed on — demos use one fixed port for both directions,
    ///     matching the `ports` entitlement's host==container convention.
    ///   - onMessage: called on a background thread for every inbound
    ///     message. Must not touch KMS/Canvas directly — hand data off to
    ///     the render loop via a lock-guarded field, the same pattern
    ///     RemoteCamSession uses (see each demo's main.swift).
    public init(peers: [String], listenPort: UInt16, onMessage: @escaping (UInt8, [UInt8]) -> Void) {
        self.peers = peers
        self.listenPort = listenPort
        self.onMessage = onMessage
    }

    /// Starts listening on a background thread. Throws if the listener
    /// itself can't be set up (bind/listen failure); accept-loop errors
    /// after that are per-connection and never surfaced here.
    public func start() throws {
        #if canImport(Glibc)
            let fd = socket(AF_INET6, Int32(SOCK_STREAM.rawValue), 0)
        #else
            let fd = socket(AF_INET6, SOCK_STREAM, 0)
        #endif
        guard fd >= 0 else { throw MeshFanoutError.listenFailed(step: "socket", errno: errno) }

        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        // Accept both IPv4-mapped and native IPv6 connections on one socket,
        // since mesh dials may arrive as either depending on resolver
        // behavior (dialMeshHost tries every family getaddrinfo returns).
        var v6Only: Int32 = 0
        setsockopt(fd, Int32(IPPROTO_IPV6), IPV6_V6ONLY, &v6Only, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in6()
        addr.sin6_family = sa_family_t(AF_INET6)
        addr.sin6_port = listenPort.bigEndian
        addr.sin6_addr = in6addr_any
        let bindResult = withUnsafePointer(to: &addr) { ptr -> Int32 in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                bind(fd, sa, socklen_t(MemoryLayout<sockaddr_in6>.size))
            }
        }
        guard bindResult == 0 else {
            let e = errno
            close(fd)
            throw MeshFanoutError.listenFailed(step: "bind", errno: e)
        }
        guard listen(fd, 16) == 0 else {
            let e = errno
            close(fd)
            throw MeshFanoutError.listenFailed(step: "listen", errno: e)
        }

        let thread = Thread { [weak self] in self?.acceptLoop(fd) }
        thread.name = "MeshFanout.accept"
        thread.start()
    }

    private func acceptLoop(_ fd: Int32) {
        while true {
            let client = accept(fd, nil, nil)
            guard client >= 0 else { continue }  // transient accept error; keep serving
            Thread.detachNewThread { [weak self] in
                defer { close(client) }
                guard let (type, payload) = readFrame(client) else { return }
                self?.onMessage(type, payload)
            }
        }
    }

    /// Fire-and-forget: connects to every peer concurrently and sends one
    /// frame each, on its own thread per peer. Returns immediately — a slow
    /// or unreachable peer only ever delays/drops its own delivery, never
    /// the caller or any other peer's delivery.
    public func broadcast(type: UInt8, payload: [UInt8] = []) {
        for host in peers {
            let port = listenPort
            Thread.detachNewThread {
                guard let fd = try? dialMeshHost(host, port: port) else { return }
                defer { close(fd) }
                sendFrame(fd, type: type, payload: payload)
            }
        }
    }
}
