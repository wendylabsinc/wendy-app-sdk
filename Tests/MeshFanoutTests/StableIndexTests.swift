import Testing
@testable import MeshFanout

@Test func indexIsWithinBounds() {
    for id in ["270", "271", "abc", ""] {
        let idx = stablePaletteIndex(for: id, paletteSize: 6)
        #expect(idx >= 0 && idx < 6)
    }
}

@Test func sameIDAlwaysProducesSameIndexWithinOneProcess() {
    let a = stablePaletteIndex(for: "270", paletteSize: 6)
    let b = stablePaletteIndex(for: "270", paletteSize: 6)
    #expect(a == b)
}

@Test func zeroPaletteSizeReturnsZero() {
    #expect(stablePaletteIndex(for: "270", paletteSize: 0) == 0)
}
