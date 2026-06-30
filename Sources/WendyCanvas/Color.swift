/// An XRGB8888 color (0x00RRGGBB), matching the DRM dumb-buffer pixel layout on
/// little-endian targets.
public struct Color: Equatable, Sendable {
    public var value: UInt32
    public init(value: UInt32) { self.value = value }
    public init(r: UInt8, g: UInt8, b: UInt8) {
        value = (UInt32(r) << 16) | (UInt32(g) << 8) | UInt32(b)
    }
    public static let black = Color(r: 0, g: 0, b: 0)
    public static let white = Color(r: 255, g: 255, b: 255)
}
