import Testing
@testable import MeshFanout

@Test func encodesTypeAndBigEndianLength() {
    let header = encodeFrameHeader(type: 0x01, payloadLength: 5)
    #expect(header == [0x01, 0x00, 0x00, 0x00, 0x05])
}

@Test func encodesLargerLengthCorrectly() {
    let header = encodeFrameHeader(type: 0x10, payloadLength: 300) // 0x12C
    #expect(header == [0x10, 0x00, 0x00, 0x01, 0x2C])
}

@Test func decodeRoundTripsWithEncode() {
    let header = encodeFrameHeader(type: 0x02, payloadLength: 42)
    let decoded = decodeFrameHeader(header)
    #expect(decoded?.type == 0x02)
    #expect(decoded?.length == 42)
}

@Test func decodeRejectsWrongByteCount() {
    #expect(decodeFrameHeader([0x01, 0x00, 0x00]) == nil)
}

@Test func decodeRejectsOversizedLength() {
    let header = encodeFrameHeader(type: 0x01, payloadLength: 2000)
    #expect(decodeFrameHeader(header, maxPayloadLength: 1024) == nil)
}
