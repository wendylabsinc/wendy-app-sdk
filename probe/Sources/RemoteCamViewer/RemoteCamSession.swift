#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import Foundation

/// Owns one demo session's TCP connection to the peer camera server and the
/// blocking connect/send/recv work, all on a dedicated background `Thread`.
///
/// Why a `Thread` and not a `Task`: this loop spends its whole life blocked
/// in `recv()`. Swift's cooperative-thread-pool executor assumes async work
/// yields regularly; parking one of its worker threads in a blocking syscall
/// for the duration of a demo session is exactly the anti-pattern the
/// concurrency runtime warns about (it can starve the pool since the number
/// of threads is bounded to roughly the core count). A plain `Thread` has no
/// such assumption, so it is the correct tool here — other probe apps here
/// use `Task`/`async` for UI-level work (see AppControlModel.swift), but
/// none of them hold a syscall blocked indefinitely the way this does.
///
/// All state shared with the main (render/input) thread is guarded by `lock`
/// and handed off via a small pending-update queue that the main loop drains
/// once per tick (see RemoteCamViewer.swift) — never touch `Canvas`/KMS from
/// this background thread.
/// `@unchecked Sendable`: every mutable field (`fd`, `state`, `stopRequested`,
/// `pending`) is only ever touched under `lock`, so it's safe to hand a
/// reference to the background `Thread` in `start()` — the compiler can't see
/// through the manual `NSLock` synchronization to verify that itself.
final class RemoteCamSession: @unchecked Sendable {
    enum State: Equatable {
        case idle
        case connecting
        case streaming
        case error(String)
    }

    enum Update {
        case state(State)
        case frame(width: Int, height: Int, rgba: [UInt8])
    }

    private let lock = NSLock()
    private var fd: Int32 = -1
    private var state: State = .idle
    private var stopRequested = false
    private var pending: [Update] = []

    /// Main-thread-safe snapshot of the current state (for deciding what a
    /// button tap should do).
    var currentState: State {
        lock.lock(); defer { lock.unlock() }
        return state
    }

    /// Drains updates queued since the last call. Main-thread only.
    func drainUpdates() -> [Update] {
        lock.lock(); defer { lock.unlock() }
        guard !pending.isEmpty else { return [] }
        let u = pending
        pending.removeAll(keepingCapacity: true)
        return u
    }

    /// Kicks off a session on a background thread. No-op if already
    /// connecting/streaming. Safe to call from the main thread.
    func start(host: String, port: UInt16) {
        lock.lock()
        switch state {
        case .idle, .error: break
        case .connecting, .streaming: lock.unlock(); return
        }
        state = .connecting
        stopRequested = false
        pending.append(.state(.connecting))
        lock.unlock()

        let thread = Thread { [weak self] in self?.run(host: host, port: port) }
        thread.name = "RemoteCamSession"
        thread.stackSize = 256 * 1024
        thread.start()
    }

    /// Requests a graceful stop: sends CMD_STOP and shuts the socket down so
    /// the background thread's blocking `recv()` unblocks immediately.
    /// `shutdown()` (unlike `close()`) is well-defined to call from a thread
    /// other than the one blocked in the read — that's why this doesn't
    /// close the fd itself; only `run()` ever closes it, avoiding a
    /// close-from-two-threads race.
    ///
    /// If called while still mid-connect (fd not yet assigned), the request
    /// is latched via `stopRequested` and honored as soon as `run()` acquires
    /// the socket, so a tap-to-stop during a slow dial isn't lost.
    func stop() {
        lock.lock()
        stopRequested = true
        let socket = fd
        lock.unlock()
        guard socket >= 0 else { return }
        sendFrame(socket, type: .cmdStop)
        shutdown(socket, Int32(SHUT_RDWR))
    }

    private func setState(_ s: State) {
        lock.lock()
        state = s
        pending.append(.state(s))
        lock.unlock()
    }

    private func run(host: String, port: UInt16) {
        let socketFD: Int32
        do {
            socketFD = try dialMeshHost(host, port: port)
        } catch {
            setState(.error("\(error)"))
            return
        }

        lock.lock()
        if stopRequested {
            lock.unlock()
            close(socketFD)
            setState(.idle)
            return
        }
        fd = socketFD
        lock.unlock()

        guard sendFrame(socketFD, type: .cmdStart) else {
            finish(socketFD, .error("failed to send CMD_START"))
            return
        }
        setState(.streaming)

        while true {
            guard let (type, payload) = readFrame(socketFD) else {
                // EOF, recv() error, or shutdown() from stop() — all treated
                // as a normal end of session per the protocol doc.
                break
            }
            switch type {
            case RemoteCamFrameType.frameRGB.rawValue:
                guard let decoded = decodeFrameRGB(payload) else { continue } // drop malformed frame
                lock.lock()
                pending.append(.frame(width: decoded.width, height: decoded.height, rgba: decoded.rgba))
                lock.unlock()
            case RemoteCamFrameType.err.rawValue:
                let msg = String(bytes: payload, encoding: .utf8) ?? "unknown error"
                finish(socketFD, .error("peer: \(msg)"))
                return
            default:
                continue // unknown frame type; ignore per protocol note
            }
        }

        finish(socketFD, .idle)
    }

    private func finish(_ socketFD: Int32, _ s: State) {
        close(socketFD)
        lock.lock()
        fd = -1
        lock.unlock()
        setState(s)
    }
}
