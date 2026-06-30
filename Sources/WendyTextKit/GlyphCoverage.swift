/// A rasterized glyph: an 8-bit coverage mask plus placement metrics (pixels).
public struct GlyphCoverage: Equatable, Sendable {
    public let width: Int
    public let height: Int
    /// Left offset from the pen origin to the bitmap's left edge.
    public let bearingX: Int
    /// Offset from the baseline to the bitmap's top edge (stb convention: usually negative = above baseline).
    public let bearingY: Int
    /// Horizontal pen advance, in pixels.
    public let advance: Float
    /// `width * height` coverage values, 0…255, row-major. Empty when width*height == 0.
    public let pixels: [UInt8]

    public init(width: Int, height: Int, bearingX: Int, bearingY: Int, advance: Float, pixels: [UInt8]) {
        self.width = width
        self.height = height
        self.bearingX = bearingX
        self.bearingY = bearingY
        self.advance = advance
        self.pixels = pixels
    }
}
