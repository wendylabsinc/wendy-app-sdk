import WendyCanvas
import WendyTextKit

/// Paints a KMSWidget tree into a Canvas at absolute offsets. Portable: no DRM.
public enum KMSRenderer {
    public static func render(_ root: KMSWidget, into canvas: Canvas, font: FontFace) {
        draw(root, originX: 0, originY: 0, canvas: canvas, font: font)
    }

    private static func draw(_ w: KMSWidget, originX: Int, originY: Int, canvas: Canvas, font: FontFace) {
        switch w.kind {
        case .container:
            break
        case .colorRect:
            if let c = w.bgColor {
                canvas.fillRect(x: originX, y: originY, w: w.size.x, h: w.size.y, c)
            }
        case .text:
            // Baseline ~ top + ascent; approximate ascent as 0.8 * pxSize.
            let baseline = originY + Int(w.textPxSize * 0.8)
            canvas.drawText(w.text, x: originX, baseline: baseline,
                            pxSize: w.textPxSize, color: w.textColor, font: font)
        case .image:
            if w.imgWidth > 0, w.imgHeight > 0 {
                canvas.blitImage(w.rgba, width: w.imgWidth, height: w.imgHeight, x: originX, y: originY)
            }
        case .button:
            // Flat filled rect; lighter while pressed for touch feedback.
            let bg = w.pressed
                ? Color(r: 92, g: 99, b: 110)
                : Color(r: 52, g: 58, b: 66)
            canvas.fillRect(x: originX, y: originY, w: w.size.x, h: w.size.y, bg)
            if !w.label.isEmpty {
                let m = font.measure(w.label, pxSize: w.buttonPxSize)
                let tx = originX + max(0, (w.size.x - Int(m.width.rounded())) / 2)
                let ty = originY + max(0, (w.size.y - Int(m.height.rounded())) / 2)
                let baseline = ty + Int(w.buttonPxSize * 0.8)
                canvas.drawText(w.label, x: tx, baseline: baseline,
                                pxSize: w.buttonPxSize, color: w.textColor, font: font)
            }
        }
        for child in w.children {
            draw(child.widget, originX: originX + child.position.x,
                 originY: originY + child.position.y, canvas: canvas, font: font)
        }
    }
}
