import WendyTextKit

/// A software raster target over a caller-owned XRGB8888 buffer (e.g. a DRM
/// dumb buffer). All coordinates are pixels; everything clips to bounds.
public struct Canvas {
    public let width: Int
    public let height: Int
    public let stride: Int          // bytes per row
    private let base: UnsafeMutableRawPointer

    public init(base: UnsafeMutableRawPointer, width: Int, height: Int, stride: Int) {
        self.base = base
        self.width = width
        self.height = height
        self.stride = stride
    }

    @inline(__always)
    private func ptr(_ x: Int, _ y: Int) -> UnsafeMutablePointer<UInt32> {
        (base + y * stride + x * MemoryLayout<UInt32>.stride).assumingMemoryBound(to: UInt32.self)
    }

    public func pixel(x: Int, y: Int) -> UInt32 {
        guard x >= 0, y >= 0, x < width, y < height else { return 0 }
        return ptr(x, y).pointee
    }

    public func fill(_ c: Color) {
        fillRect(x: 0, y: 0, w: width, h: height, c)
    }

    public func fillRect(x: Int, y: Int, w: Int, h: Int, _ c: Color) {
        let x0 = max(0, x), y0 = max(0, y)
        let x1 = min(width, x + w), y1 = min(height, y + h)
        guard x0 < x1, y0 < y1 else { return }
        for py in y0..<y1 {
            for px in x0..<x1 { ptr(px, py).pointee = c.value }
        }
    }

    /// Alpha-composites a glyph coverage mask with `color` over the buffer.
    /// `x`,`y` are the top-left of the coverage bitmap.
    public func blit(_ cov: GlyphCoverage, x: Int, y: Int, color: Color) {
        guard cov.width > 0, cov.height > 0 else { return }
        let cr = (color.value >> 16) & 0xFF
        let cg = (color.value >> 8) & 0xFF
        let cb = color.value & 0xFF
        for row in 0..<cov.height {
            let py = y + row
            guard py >= 0, py < height else { continue }
            for col in 0..<cov.width {
                let px = x + col
                guard px >= 0, px < width else { continue }
                let a = UInt32(cov.pixels[row * cov.width + col])
                if a == 0 { continue }
                let ia = 255 - a
                let d = ptr(px, py)
                let dv = d.pointee
                let dr = (dv >> 16) & 0xFF, dg = (dv >> 8) & 0xFF, db = dv & 0xFF
                let r = (cr * a + dr * ia + 127) / 255
                let g = (cg * a + dg * ia + 127) / 255
                let b = (cb * a + db * ia + 127) / 255
                d.pointee = (r << 16) | (g << 8) | b
            }
        }
    }

    /// Alpha-composites an RGBA8 image (row-major, 4 bytes/pixel) over the buffer
    /// at (x, y), clipped to bounds. Straight (non-premultiplied) alpha.
    public func blitImage(_ rgba: [UInt8], width iw: Int, height ih: Int, x: Int, y: Int) {
        guard iw > 0, ih > 0, rgba.count >= iw * ih * 4 else { return }
        for row in 0..<ih {
            let py = y + row
            guard py >= 0, py < height else { continue }
            for col in 0..<iw {
                let px = x + col
                guard px >= 0, px < width else { continue }
                let i = (row * iw + col) * 4
                let sr = UInt32(rgba[i]), sg = UInt32(rgba[i+1]), sb = UInt32(rgba[i+2])
                let a = UInt32(rgba[i+3])
                if a == 0 { continue }
                if a == 255 {
                    self.fillRect(x: px, y: py, w: 1, h: 1, Color(value: (sr<<16)|(sg<<8)|sb))
                    continue
                }
                let ia = 255 - a
                let dv = pixel(x: px, y: py)
                let dr = (dv >> 16) & 0xFF, dg = (dv >> 8) & 0xFF, db = dv & 0xFF
                let r = (sr * a + dr * ia + 127) / 255
                let g = (sg * a + dg * ia + 127) / 255
                let b = (sb * a + db * ia + 127) / 255
                self.fillRect(x: px, y: py, w: 1, h: 1, Color(value: (r<<16)|(g<<8)|b))
            }
        }
    }

    /// Draws a single line of text with its baseline at `baseline`, pen starting at `x`.
    public func drawText(_ s: String, x: Int, baseline: Int, pxSize: Float, color: Color, font: FontFace) {
        var penX = Float(x)
        for scalar in s.unicodeScalars {
            let g = font.rasterize(scalar, pxSize: pxSize)
            if g.width > 0 {
                blit(g, x: Int(penX.rounded()) + g.bearingX, y: baseline + g.bearingY, color: color)
            }
            penX += g.advance
        }
    }
}
