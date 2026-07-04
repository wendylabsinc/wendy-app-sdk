/// Builds the 5-byte frame header: [type][4-byte big-endian length]. Pure,
/// no I/O — split out from `sendFrame` (Task 2) purely so the
/// length-encoding math is unit-testable without a live socket.
func encodeFrameHeader(type: UInt8, payloadLength: Int) -> [UInt8] {
    var header = [UInt8]()
    header.reserveCapacity(5)
    header.append(type)
    let len = UInt32(payloadLength).bigEndian
    withUnsafeBytes(of: len) { header.append(contentsOf: $0) }
    return header
}

/// Parses a 5-byte frame header. Returns nil if `bytes.count != 5` or the
/// decoded length exceeds `maxPayloadLength` — guards a corrupted length
/// from driving an unbounded allocation on the read side. Demo payloads
/// (a color byte triple, or nothing at all) are tiny, so the default cap is
/// generous, not tight.
func decodeFrameHeader(_ bytes: [UInt8], maxPayloadLength: Int = 1024) -> (type: UInt8, length: Int)? {
    guard bytes.count == 5 else { return nil }
    let length = (UInt32(bytes[1]) << 24) | (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 8) | UInt32(bytes[4])
    guard length <= UInt32(maxPayloadLength) else { return nil }
    return (bytes[0], Int(length))
}
