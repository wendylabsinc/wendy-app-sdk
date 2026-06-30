import Foundation
import CStbTrueType
import CWendyFont

/// Loads a TTF and rasterizes/measures glyphs via stb_truetype. Owns a stable
/// copy of the font bytes for stb's lifetime.
public final class FontFace {
    private let data: UnsafeMutablePointer<UInt8>?
    private let count: Int
    private var info = stbtt_fontinfo()

    public init?(ttf bytes: [UInt8]) {
        guard !bytes.isEmpty else {
            data = nil
            count = 0
            return nil
        }
        count = bytes.count
        let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
        // Assign data before the closure so all stored properties are initialized before capture.
        data = ptr
        bytes.withUnsafeBufferPointer { buf in
            ptr.update(from: buf.baseAddress!, count: count)
        }
        let offset = stbtt_GetFontOffsetForIndex(ptr, 0)
        guard offset >= 0, stbtt_InitFont(&info, ptr, offset) != 0 else {
            return nil  // deinit will call data?.deallocate()
        }
    }

    deinit { data?.deallocate() }

    public func rasterize(_ scalar: Unicode.Scalar, pxSize: Float) -> GlyphCoverage {
        let scale = stbtt_ScaleForPixelHeight(&info, pxSize)
        var advance: Int32 = 0, lsb: Int32 = 0
        stbtt_GetCodepointHMetrics(&info, Int32(scalar.value), &advance, &lsb)

        var w: Int32 = 0, h: Int32 = 0, xoff: Int32 = 0, yoff: Int32 = 0
        let bmp = stbtt_GetCodepointBitmap(&info, 0, scale, Int32(scalar.value), &w, &h, &xoff, &yoff)
        defer { if bmp != nil { stbtt_FreeBitmap(bmp, nil) } }

        let n = Int(w) * Int(h)
        var pixels = [UInt8](repeating: 0, count: n)
        if let bmp, n > 0 {
            pixels.withUnsafeMutableBytes { buf in
                if let dest = buf.baseAddress { _ = memcpy(dest, bmp, n) }
            }
        }
        return GlyphCoverage(
            width: Int(w), height: Int(h),
            bearingX: Int(xoff), bearingY: Int(yoff),
            advance: Float(advance) * scale, pixels: pixels
        )
    }

    public func measure(_ string: String, pxSize: Float) -> (width: Float, height: Float) {
        let scale = stbtt_ScaleForPixelHeight(&info, pxSize)
        var ascent: Int32 = 0, descent: Int32 = 0, lineGap: Int32 = 0
        stbtt_GetFontVMetrics(&info, &ascent, &descent, &lineGap)
        var width: Float = 0
        for scalar in string.unicodeScalars {
            var advance: Int32 = 0, lsb: Int32 = 0
            stbtt_GetCodepointHMetrics(&info, Int32(scalar.value), &advance, &lsb)
            width += Float(advance) * scale
        }
        return (width, Float(ascent - descent) * scale)
    }
}

// Safe to send/share: after init, `info` is only read by stb (no mutation),
// and the owned font-bytes buffer is freed only in deinit.
extension FontFace: @unchecked Sendable {}

public extension FontFace {
    /// The embedded WendySans font (compiled into the binary; no resource bundle).
    static func bundled() -> FontFace {
        let count = Int(wendy_sans_ttf_len)
        let bytes = [UInt8](UnsafeBufferPointer(start: wendy_sans_ttf_ptr, count: count))
        guard let face = FontFace(ttf: bytes) else {
            fatalError("embedded WendySans.ttf failed to parse (\(count) bytes)")
        }
        return face
    }
}
