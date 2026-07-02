import Testing
import WendyCanvas
import WendyTextKit
@testable import WendyKMSBackend

// EnvironmentValues has a package-gated init upstream, so tests exercise the
// internal _updateButtonStorage helper — the same pattern as _updateImageStorage.
@MainActor
@Test func createButtonMakesAButtonWidget() {
    let b = WendyKMSBackend()
    #expect(b.createButton().kind == .button)
}

@MainActor
@Test func updateButtonStorageSetsLabelActionAndNaturalSize() {
    let b = WendyKMSBackend()
    let w = b.createButton()
    var fired = false
    b._updateButtonStorage(w, label: "Start", pxSize: 20,
                           color: Color(r: 255, g: 255, b: 255)) { fired = true }
    #expect(w.label == "Start")
    #expect(w.buttonPxSize == 20)
    #expect(w.naturalButtonSize.x > 0 && w.naturalButtonSize.y > 0)
    #expect(b.naturalSize(of: w) == w.naturalButtonSize)
    w.action?()
    #expect(fired)
}

@MainActor
@Test func buttonNaturalSizeExceedsBareLabelMeasurement() {
    let b = WendyKMSBackend()
    let w = b.createButton()
    b._updateButtonStorage(w, label: "Stop", pxSize: 20,
                           color: Color(r: 255, g: 255, b: 255)) {}
    let m = WendyTextKit.FontFace.bundled().measure("Stop", pxSize: 20)
    #expect(w.naturalButtonSize.x > Int(m.width))
    #expect(w.naturalButtonSize.y > Int(m.height))
}

@MainActor
@Test func rendererPaintsButtonBackgroundAndPressedHighlight() {
    // 60x30 canvas, one 60x30 button at origin: corner pixel must change from
    // black when painted, and change again when pressed (lighter fill).
    let width = 60, height = 30
    var pixels = [UInt32](repeating: 0, count: width * height)
    let w = KMSWidget(.button)
    w.size = SIMD2(width, height)
    w.label = ""     // no text: we assert on the background only
    func paint() -> UInt32 {
        pixels.withUnsafeMutableBytes { buf in
            let canvas = Canvas(base: buf.baseAddress!, width: width,
                                height: height, stride: width * 4)
            canvas.fill(Color(r: 0, g: 0, b: 0))
            KMSRenderer.render(w, into: canvas, font: WendyTextKit.FontFace.bundled())
            return buf.load(fromByteOffset: 0, as: UInt32.self)
        }
    }
    let idle = paint()
    #expect(idle != 0)              // background drawn
    w.pressed = true
    let pressed = paint()
    #expect(pressed != idle)        // pressed state visibly different
}
