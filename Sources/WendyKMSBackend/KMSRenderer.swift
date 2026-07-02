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
            break  // TODO: Task 4: button rendering
        }
        for child in w.children {
            draw(child.widget, originX: originX + child.position.x,
                 originY: originY + child.position.y, canvas: canvas, font: font)
        }
    }
}
