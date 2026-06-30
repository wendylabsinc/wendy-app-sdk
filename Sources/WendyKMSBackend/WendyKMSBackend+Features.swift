import SwiftCrossUI
import WendyCanvas

extension WendyKMSBackend: BackendFeatures.Colors {
    // MARK: Color conversion

    /// Converts a SwiftCrossUI 0…1 Float RGBA color to the WendyCanvas 0…255 RGB color.
    static func toColor(_ c: SwiftCrossUI.Color.Resolved) -> WendyCanvas.Color {
        func u8(_ f: Float) -> UInt8 { UInt8(max(0, min(255, (f * 255).rounded()))) }
        return WendyCanvas.Color(r: u8(c.red), g: u8(c.green), b: u8(c.blue))
    }

    // MARK: Colors

    public func createColorableRectangle() -> KMSWidget { KMSWidget(.colorRect) }

    public func setColor(ofColorableRectangle widget: KMSWidget, to color: SwiftCrossUI.Color.Resolved) {
        widget.bgColor = Self.toColor(color)
        markAllDirty()
    }

    // resolveAdaptiveColor(_:in:) uses the default implementation from BackendFeatures.Colors.
}
