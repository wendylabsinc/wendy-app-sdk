#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import Foundation

// Wire protocol for the RemoteCam demo (Device A viewer <-> Device B camera
// server), per specs/remotecam-protocol.md. Raw TCP, big-endian lengths.
// Frame = [1-byte type][4-byte uint32 length][payload].

enum RemoteCamFrameType: UInt8 {
    case cmdStart = 0x01
    case cmdStop = 0x02
    case frameRGB = 0x10
    case err = 0x7F
}

enum RemoteCamError: Error, CustomStringConvertible {
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

/// Resolves `host` (the mesh hostname, e.g. device-<id>.cloud.wendy.dev) via
/// getaddrinfo and connects to the first address that accepts, trying both
/// address families the resolver returns. Blocking; call off the main thread.
func dialMeshHost(_ host: String, port: UInt16) throws -> Int32 {
    var hints = addrinfo()
    hints.ai_family = AF_UNSPEC
    #if canImport(Glibc)
    // Glibc's SOCK_STREAM is __socket_type (its own raw-value enum); Darwin's
    // is already Int32. addrinfo.ai_socktype is Int32 on both.
    hints.ai_socktype = Int32(SOCK_STREAM.rawValue)
    #else
    hints.ai_socktype = SOCK_STREAM
    #endif
    var result: UnsafeMutablePointer<addrinfo>?
    let rc = getaddrinfo(host, String(port), &hints, &result)
    guard rc == 0, let first = result else {
        throw RemoteCamError.resolveFailed(host: host, code: rc)
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
    throw RemoteCamError.connectFailed(host: host, port: port, errno: lastErrno)
}

/// Writes every byte of `bytes` to `fd`, retrying on EINTR and short writes.
/// Returns false on any fatal error (caller should treat the connection as dead).
@discardableResult
func sendAll(_ fd: Int32, _ bytes: [UInt8]) -> Bool {
    guard !bytes.isEmpty else { return true }
    return bytes.withUnsafeBytes { buf -> Bool in
        var offset = 0
        while offset < buf.count {
            let n = send(fd, buf.baseAddress!.advanced(by: offset), buf.count - offset, 0)
            if n > 0 {
                offset += n
                continue
            }
            if n < 0, errno == EINTR { continue }
            return false
        }
        return true
    }
}

/// Reads exactly `count` bytes from `fd`, retrying on EINTR and short reads.
/// Returns nil on EOF or a fatal error (including a `shutdown()` issued by
/// another thread to interrupt a blocking read — see RemoteCamSession.stop()).
func recvExact(_ fd: Int32, count: Int) -> [UInt8]? {
    guard count > 0 else { return [] }
    var buffer = [UInt8](repeating: 0, count: count)
    let ok = buffer.withUnsafeMutableBytes { buf -> Bool in
        var offset = 0
        while offset < count {
            let n = recv(fd, buf.baseAddress!.advanced(by: offset), count - offset, 0)
            if n > 0 {
                offset += n
                continue
            }
            if n < 0, errno == EINTR { continue }
            return false // n == 0 (peer closed) or a fatal recv() error
        }
        return true
    }
    return ok ? buffer : nil
}

/// Sends one framed message: `[type][big-endian uint32 length][payload]`.
@discardableResult
func sendFrame(_ fd: Int32, type: RemoteCamFrameType, payload: [UInt8] = []) -> Bool {
    var header = [UInt8]()
    header.reserveCapacity(5)
    header.append(type.rawValue)
    let len = UInt32(payload.count).bigEndian
    withUnsafeBytes(of: len) { header.append(contentsOf: $0) }
    return sendAll(fd, header) && sendAll(fd, payload)
}

/// Reads one framed message (5-byte header + payload). Blocking. Returns nil
/// on disconnect/shutdown or a malformed/oversized length (protocol error).
func readFrame(_ fd: Int32) -> (type: UInt8, payload: [UInt8])? {
    guard let header = recvExact(fd, count: 5) else { return nil }
    let type = header[0]
    let length = (UInt32(header[1]) << 24) | (UInt32(header[2]) << 16)
        | (UInt32(header[3]) << 8) | UInt32(header[4])
    // Sanity cap well above one 320x240 RGB frame (~230 KiB) so a corrupted
    // length can't drive an unbounded allocation.
    guard length <= 16 * 1024 * 1024 else { return nil }
    guard let payload = recvExact(fd, count: Int(length)) else { return nil }
    return (type, payload)
}

/// Decodes a FRAME_RGB payload (`[u16 width][u16 height][w*h*3 RGB bytes]`)
/// into an RGBA8 buffer (alpha=255) ready for `Canvas.blitImage`.
func decodeFrameRGB(_ payload: [UInt8]) -> (width: Int, height: Int, rgba: [UInt8])? {
    guard payload.count >= 4 else { return nil }
    let width = (Int(payload[0]) << 8) | Int(payload[1])
    let height = (Int(payload[2]) << 8) | Int(payload[3])
    guard width > 0, height > 0, payload.count == 4 + width * height * 3 else { return nil }

    var rgba = [UInt8](repeating: 255, count: width * height * 4)
    var src = 4
    var dst = 0
    for _ in 0..<(width * height) {
        rgba[dst] = payload[src]
        rgba[dst + 1] = payload[src + 1]
        rgba[dst + 2] = payload[src + 2]
        // rgba[dst + 3] left at 255 (opaque)
        src += 3
        dst += 4
    }
    return (width, height, rgba)
}
