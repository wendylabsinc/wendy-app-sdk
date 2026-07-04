import Testing
@testable import MeshFanout

@Test func parsesCommaSeparatedIDs() {
    #expect(parseMeshPeers("270,271,272") == [
        "device-270.cloud.wendy.dev",
        "device-271.cloud.wendy.dev",
        "device-272.cloud.wendy.dev",
    ])
}

@Test func skipsBlankEntriesAndWhitespace() {
    #expect(parseMeshPeers(" 270 ,,271,") == [
        "device-270.cloud.wendy.dev",
        "device-271.cloud.wendy.dev",
    ])
}

@Test func emptyStringProducesNoPeers() {
    #expect(parseMeshPeers("") == [])
}

@Test func excludesSelfID() {
    #expect(parseMeshPeers("270,271,272", excluding: "271") == [
        "device-270.cloud.wendy.dev",
        "device-272.cloud.wendy.dev",
    ])
}
