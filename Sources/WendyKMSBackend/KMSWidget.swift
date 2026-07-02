import WendyCanvas

/// A retained draw-node. SwiftCrossUI builds/positions the tree via the backend;
/// KMSRenderer paints it. One class with a `kind` keeps the model small.
public final class KMSWidget {
    public enum Kind { case container, colorRect, text, image, button }
    public var kind: Kind
    public var size: SIMD2<Int> = .zero
    public var children: [(widget: KMSWidget, position: SIMD2<Int>)] = []

    // colorRect
    public var bgColor: Color?
    // text
    public var text: String = ""
    public var textPxSize: Float = 16
    public var textColor: Color = .white
    // image (RGBA8)
    public var rgba: [UInt8] = []
    public var imgWidth: Int = 0
    public var imgHeight: Int = 0
    // button
    public var label: String = ""
    public var pressed = false
    public var action: (() -> Void)?
    public var buttonPxSize: Float = 16
    public var naturalButtonSize: SIMD2<Int> = .zero

    public init(_ kind: Kind) { self.kind = kind }
}
