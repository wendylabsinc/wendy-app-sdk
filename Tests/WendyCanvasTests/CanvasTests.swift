import Testing
import WendyTextKit
@testable import WendyCanvas

private func makeCanvas(_ w: Int, _ h: Int) -> (Canvas, UnsafeMutableRawPointer) {
    let stride = w * 4
    let base = UnsafeMutableRawPointer.allocate(byteCount: stride * h, alignment: 4)
    base.initializeMemory(as: UInt8.self, repeating: 0, count: stride * h)
    return (Canvas(base: base, width: w, height: h, stride: stride), base)
}

@Test func fillSetsEveryPixel() {
    let (c, base) = makeCanvas(4, 4); defer { base.deallocate() }
    c.fill(Color(r: 0x12, g: 0x34, b: 0x56))
    #expect(c.pixel(x: 0, y: 0) == 0x00123456)
    #expect(c.pixel(x: 3, y: 3) == 0x00123456)
}

@Test func fillRectClipsAndSetsRegion() {
    let (c, base) = makeCanvas(4, 4); defer { base.deallocate() }
    c.fillRect(x: 1, y: 1, w: 100, h: 100, Color(r: 255, g: 0, b: 0)) // overdraws; must clip
    #expect(c.pixel(x: 0, y: 0) == 0)            // outside
    #expect(c.pixel(x: 1, y: 1) == 0x00FF0000)   // inside
    #expect(c.pixel(x: 3, y: 3) == 0x00FF0000)
}

@Test func blitCompositesByCoverage() {
    let (c, base) = makeCanvas(2, 1); defer { base.deallocate() }
    // full coverage at (0,0), zero at (1,0)
    let cov = GlyphCoverage(width: 2, height: 1, bearingX: 0, bearingY: 0, advance: 2, pixels: [255, 0])
    c.blit(cov, x: 0, y: 0, color: Color(r: 0xAA, g: 0xBB, b: 0xCC))
    #expect(c.pixel(x: 0, y: 0) == 0x00AABBCC)   // fully covered → color
    #expect(c.pixel(x: 1, y: 0) == 0)            // zero coverage → unchanged
}

@Test func blitMidRangeAlpha() {
    let (c, base) = makeCanvas(1, 1); defer { base.deallocate() }
    // background is black (0), blit white with coverage 128
    // expected: r = (255 * 128 + 0 * 127 + 127) / 255 = 32767 / 255 = 128
    let cov = GlyphCoverage(width: 1, height: 1, bearingX: 0, bearingY: 0, advance: 1, pixels: [128])
    c.blit(cov, x: 0, y: 0, color: Color(r: 255, g: 255, b: 255))
    let pixel = c.pixel(x: 0, y: 0)
    let r = (pixel >> 16) & 0xFF
    let g = (pixel >> 8) & 0xFF
    let b = pixel & 0xFF
    #expect(r > 0 && r < 255)
    #expect(g > 0 && g < 255)
    #expect(b > 0 && b < 255)
    #expect(r == 128)
    #expect(g == 128)
    #expect(b == 128)
    #expect(pixel == 0x00808080)
}

@Test func drawTextAdvancesRightward() {
    let (c, base) = makeCanvas(200, 64); defer { base.deallocate() }
    let font = FontFace.bundled()
    c.drawText("AB", x: 4, baseline: 48, pxSize: 32, color: Color(r: 255, g: 255, b: 255), font: font)
    // Some pixel must be lit (text drawn), and lit pixels should span rightward past the first glyph.
    var litXs: [Int] = []
    for y in 0..<64 { for x in 0..<200 where c.pixel(x: x, y: y) != 0 { litXs.append(x) } }
    #expect(!litXs.isEmpty)
    #expect((litXs.max() ?? 0) > (litXs.min() ?? 0) + 10)
}

@Test func blitImageCompositesRGBA() {
    let (c, base) = makeCanvas(3, 1); defer { base.deallocate() }
    // pixel0 opaque red, pixel1 opaque green, pixel2 transparent (alpha 0)
    let rgba: [UInt8] = [255,0,0,255,  0,255,0,255,  0,0,255,0]
    c.blitImage(rgba, width: 3, height: 1, x: 0, y: 0)
    #expect(c.pixel(x: 0, y: 0) == 0x00FF0000)
    #expect(c.pixel(x: 1, y: 0) == 0x0000FF00)
    #expect(c.pixel(x: 2, y: 0) == 0)            // alpha 0 -> destination unchanged
}

@Test func blitImageClips() {
    let (c, base) = makeCanvas(2, 2); defer { base.deallocate() }
    let rgba = [UInt8](repeating: 255, count: 4 * 4 * 4) // 4x4 opaque white
    c.blitImage(rgba, width: 4, height: 4, x: 1, y: 1)   // overhangs
    #expect(c.pixel(x: 0, y: 0) == 0)            // outside the blit
    #expect(c.pixel(x: 1, y: 1) == 0x00FFFFFF)   // inside
}
