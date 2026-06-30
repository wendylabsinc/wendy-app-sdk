import Testing
import SwiftCrossUI
@testable import WendyKMSBackend
import WendyCanvas

// Note: EnvironmentValues has only a package-level init(backend:) defined in swift-cross-ui,
// which is inaccessible from wendy-app-sdk. The imageViewStoresPixels test exercises the
// same storage behavior through the internal _updateImageStorage helper (accessible via
// @testable import) so that the asserted behavior is preserved without needing to construct
// an EnvironmentValues. The colorableRectangle test is unaffected.

@MainActor
@Test func colorableRectangleStoresColor() {
    let b = WendyKMSBackend()
    let r = b.createColorableRectangle()
    b.setColor(ofColorableRectangle: r, to: Color.Resolved(red: 1.0, green: 0.0, blue: 0.0, opacity: 1.0))
    #expect(r.kind == .colorRect)
    #expect(r.bgColor == WendyCanvas.Color(r: 255, g: 0, b: 0))
}

@MainActor
@Test func imageViewStoresPixels() {
    let b = WendyKMSBackend()
    let v = b.createImageView()
    // Exercises the internal _updateImageStorage helper (not the environment path of updateImageView), because EnvironmentValues is not constructible out-of-module — a known coverage gap.
    b._updateImageStorage(v, rgbaData: [1, 2, 3, 4], width: 1, height: 1, dataHasChanged: true)
    #expect(v.kind == .image)
    #expect(v.imgWidth == 1 && v.imgHeight == 1 && v.rgba.count == 4)
}
