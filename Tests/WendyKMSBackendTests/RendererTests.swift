import Testing
import WendyCanvas
import WendyTextKit
@testable import WendyKMSBackend

private func makeCanvas(_ w: Int, _ h: Int) -> (Canvas, UnsafeMutableRawPointer) {
    let stride = w * 4
    let base = UnsafeMutableRawPointer.allocate(byteCount: stride * h, alignment: 4)
    base.initializeMemory(as: UInt8.self, repeating: 0, count: stride * h)
    return (Canvas(base: base, width: w, height: h, stride: stride), base)
}

@Test func rendersColorRectAtChildOffset() {
    let (canvas, base) = makeCanvas(20, 20); defer { base.deallocate() }
    let root = KMSWidget(.container); root.size = SIMD2(20, 20)
    let rect = KMSWidget(.colorRect); rect.size = SIMD2(5, 5)
    rect.bgColor = Color(r: 0xFF, g: 0, b: 0)
    root.children = [(rect, SIMD2(10, 10))]
    KMSRenderer.render(root, into: canvas, font: FontFace.bundled())
    #expect(canvas.pixel(x: 12, y: 12) == 0x00FF0000)   // inside the offset rect
    #expect(canvas.pixel(x: 0, y: 0) == 0)               // outside
}

@Test func rendersNestedOffsetsAccumulate() {
    let (canvas, base) = makeCanvas(40, 40); defer { base.deallocate() }
    let root = KMSWidget(.container); root.size = SIMD2(40, 40)
    let mid = KMSWidget(.container); mid.size = SIMD2(30, 30)
    let dot = KMSWidget(.colorRect); dot.size = SIMD2(2, 2); dot.bgColor = Color(r: 0, g: 0xFF, b: 0)
    mid.children = [(dot, SIMD2(5, 5))]
    root.children = [(mid, SIMD2(10, 10))]
    KMSRenderer.render(root, into: canvas, font: FontFace.bundled())
    #expect(canvas.pixel(x: 16, y: 16) == 0x0000FF00)    // 10+5 .. +2
    #expect(canvas.pixel(x: 11, y: 11) == 0)
}

@Test func rendersTextPixels() {
    let (canvas, base) = makeCanvas(300, 80); defer { base.deallocate() }
    let root = KMSWidget(.container); root.size = SIMD2(300, 80)
    let t = KMSWidget(.text); t.text = "Hi"; t.textPxSize = 48
    t.textColor = Color(r: 0xFF, g: 0xFF, b: 0xFF); t.size = SIMD2(120, 60)
    root.children = [(t, SIMD2(10, 5))]
    KMSRenderer.render(root, into: canvas, font: FontFace.bundled())
    var lit = 0
    for y in 0..<80 { for x in 0..<300 where canvas.pixel(x: x, y: y) != 0 { lit += 1 } }
    #expect(lit > 0)
}
