import Testing
@testable import WendyTextKit

@Test func bundledFontLoads() {
    let face = FontFace.bundled()
    let g = face.rasterize("A", pxSize: 48)
    #expect(g.width > 0)
    #expect(g.height > 0)
    #expect(g.pixels.count == g.width * g.height)
    #expect(g.advance > 0)
    // Some pixel in a capital A at 48px must be (near) fully covered.
    #expect(g.pixels.contains { $0 > 200 })
}

@Test func spaceHasAdvanceButNoCoverage() {
    let face = FontFace.bundled()
    let g = face.rasterize(" ", pxSize: 48)
    #expect(g.advance > 0)
    #expect(g.pixels.allSatisfy { $0 == 0 })   // empty or all-zero coverage
}

@Test func measureGrowsWithText() {
    let face = FontFace.bundled()
    let one = face.measure("i", pxSize: 32).width
    let many = face.measure("iiiii", pxSize: 32).width
    #expect(many > one)
    #expect(face.measure("Hello", pxSize: 32).height > 0)
}

@Test func failableInitRejectsGarbage() {
    #expect(FontFace(ttf: [0, 1, 2, 3]) == nil)
}
