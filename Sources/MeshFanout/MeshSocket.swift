#if canImport(Glibc)
    import Glibc
#elseif canImport(Darwin)
    import Darwin
#endif
import Foundation

/// Errors from the low-level mesh TCP dial. Mirrors
/// `probe/Sources/RemoteCamViewer/RemoteCamProtocol.swift`'s
/// `RemoteCamError` (same repo, different target) — duplicated rather than
/// shared since RemoteCamViewer doesn't expose these as a library product.
enum MeshSocketError: Error, CustomStringConvertible {
    case resolveFailed(host: String, code: Int32)
    case connectFailed(host: String, port: UInt16, errno: Int32)

    var description: String {
        switch self {
        case .resolveFailed(let host, let code):
            return "getaddrinfo(\(host)) failed (code \(code))"
        case .connectFailed(let host, let port, let errno):
            return "connect(\(host):\(port)) failed (errno \(errno))"
        }
    }
}

/// Resolves `host` via getaddrinfo and connects to the first address that
/// accepts, trying every address family the resolver returns. Blocking;
/// call off the main thread.
func dialMeshHost(_ host: String, port: UInt16) throws -> Int32 {
    var hints = addrinfo()
    hints.ai_family = AF_UNSPEC
    #if canImport(Glibc)
        hints.ai_socktype = Int32(SOCK_STREAM.rawValue)
    #else
        hints.ai_socktype = SOCK_STREAM
    #endif
    var result: UnsafeMutablePointer<addrinfo>?
    let rc = getaddrinfo(host, String(port), &hints, &result)
    guard rc == 0, let first = result else {
        throw MeshSocketError.resolveFailed(host: host, code: rc)
    }
    defer { freeaddrinfo(result) }

    var lastErrno: Int32 = ENOENT
    var cursor: UnsafeMutablePointer<addrinfo>? = first
    while let addr = cursor {
        let fd = socket(addr.pointee.ai_family, addr.pointee.ai_socktype, addr.pointee.ai_protocol)
        if fd >= 0 {
            if connect(fd, addr.pointee.ai_addr, addr.pointee.ai_addrlen) == 0 {
                return fd
            }
            lastErrno = errno
            close(fd)
        } else {
            lastErrno = errno
        }
        cursor = addr.pointee.ai_next
    }
    throw MeshSocketError.connectFailed(host: host, port: port, errno: lastErrno)
}

/// Writes every byte of `bytes` to `fd`, retrying on EINTR and short writes.
@discardableResult
func sendAll(_ fd: Int32, _ bytes: [UInt8]) -> Bool {
    guard !bytes.isEmpty else { return true }
    return bytes.withUnsafeBytes { buf -> Bool in
        var offset = 0
        while offset < buf.count {
            let n = send(fd, buf.baseAddress!.advanced(by: offset), buf.count - offset, 0)
            if n > 0 { offset += n; continue }
            if n < 0, errno == EINTR { continue }
            return false
        }
        return true
    }
}

/// Reads exactly `count` bytes from `fd`, retrying on EINTR. Returns nil on
/// EOF or a fatal error.
func recvExact(_ fd: Int32, count: Int) -> [UInt8]? {
    guard count > 0 else { return [] }
    var buffer = [UInt8](repeating: 0, count: count)
    let ok = buffer.withUnsafeMutableBytes { buf -> Bool in
        var offset = 0
        while offset < count {
            let n = recv(fd, buf.baseAddress!.advanced(by: offset), count - offset, 0)
            if n > 0 { offset += n; continue }
            if n < 0, errno == EINTR { continue }
            return false
        }
        return true
    }
    return ok ? buffer : nil
}
