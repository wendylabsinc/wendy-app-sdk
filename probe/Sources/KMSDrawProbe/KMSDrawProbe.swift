import Foundation
import WendyKMSDRM
import WendyCanvas
import WendyTextKit

@main
struct KMSDrawProbe {
    static func main() {
        print("=== WendyKMS draw probe ===")
        let path = ProcessInfo.processInfo.environment["WENDY_KMS_DEVICE"] ?? "/dev/dri/card0"
        print("opening \(path) (stop sh.wendy.shell first so KMS is free)")

        var display = WendyKMSDisplay()
        var errBuf = [CChar](repeating: 0, count: 256)
        let rc = wendy_kms_open(path, &display, &errBuf, 256)
        guard rc == 0 else {
            let msg = errBuf.withUnsafeBytes { String(bytes: $0.prefix(while: { $0 != 0 }), encoding: .utf8) ?? "" }
            print("wendy_kms_open failed (rc=\(rc)): \(msg)")
            print("If another DRM master holds the device, stop the shell and retry.")
            exit(1)
        }
        guard let pixels = display.pixels else {
            print("no framebuffer mapped"); wendy_kms_close(&display); exit(1)
        }
        let w = Int(display.width), h = Int(display.height), stride = Int(display.stride)
        print("display \(w)x\(h) stride=\(stride)")

        let canvas = Canvas(base: pixels, width: w, height: h, stride: stride)
        let font = FontFace.bundled()

        // Background gradient-ish fill: dark navy, with a centered panel.
        canvas.fill(Color(r: 0x10, g: 0x14, b: 0x20))
        canvas.fillRect(x: w / 8, y: h / 8, w: w * 3 / 4, h: h * 3 / 4, Color(r: 0x1C, g: 0x24, b: 0x38))

        let amber = Color(r: 0xF5, g: 0xA6, b: 0x23)
        canvas.drawText("WendyOS — WendyKMSBackend", x: w / 8 + 40, baseline: h / 8 + 80,
                        pxSize: 48, color: amber, font: font)
        canvas.drawText("software KMS scanout · \(w)x\(h)", x: w / 8 + 40, baseline: h / 8 + 140,
                        pxSize: 28, color: .white, font: font)
        canvas.drawText("the quick brown fox jumps over the lazy dog 0123456789",
                        x: w / 8 + 40, baseline: h / 8 + 200, pxSize: 28, color: .white, font: font)

        print("drawn; holding for 20s (or until SIGINT)")
        sleep(20)

        wendy_kms_close(&display)
        print("closed; restored prior CRTC. Restart the shell now.")
    }
}
