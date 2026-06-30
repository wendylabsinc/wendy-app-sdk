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
        wendy_kms_flush_stdout()

        let canvas = Canvas(base: pixels, width: w, height: h, stride: stride)
        let font = FontFace.bundled()

        // Edge-to-edge full-screen test pattern.
        let navy = Color(r: 0x10, g: 0x14, b: 0x20)
        let amber = Color(r: 0xF5, g: 0xA6, b: 0x23)
        let cyan = Color(r: 0x21, g: 0xD0, b: 0xC0)
        canvas.fill(navy)                                   // whole screen
        canvas.fillRect(x: 0, y: 0, w: w, h: 96, amber)     // full-width top bar
        canvas.fillRect(x: 0, y: h - 96, w: w, h: 96, amber) // full-width bottom bar
        // Corner markers prove the buffer reaches all four physical corners.
        let m = 64
        canvas.fillRect(x: 0, y: 0, w: m, h: m, cyan)
        canvas.fillRect(x: w - m, y: 0, w: m, h: m, cyan)
        canvas.fillRect(x: 0, y: h - m, w: m, h: m, cyan)
        canvas.fillRect(x: w - m, y: h - m, w: m, h: m, cyan)

        canvas.drawText("WendyOS — WendyKMSBackend", x: 40, baseline: 66, pxSize: 48, color: navy, font: font)
        canvas.drawText("full-screen software KMS scanout · \(w)x\(h)", x: 40, baseline: h / 2,
                        pxSize: 40, color: amber, font: font)
        canvas.drawText("the quick brown fox jumps over the lazy dog 0123456789", x: 40, baseline: h / 2 + 56,
                        pxSize: 28, color: .white, font: font)

        wendy_kms_present(&display)
        wendy_kms_flush_stdout()

        // Default to a long hold so the image persists until the container is
        // stopped; re-present periodically so it stays latched on the display.
        let holdSeconds = ProcessInfo.processInfo.environment["WENDY_KMS_HOLD_SECONDS"]
            .flatMap(Int.init) ?? 86400
        print("drawn; holding for \(holdSeconds)s (stop the container to exit)")
        wendy_kms_flush_stdout()
        var elapsed = 0
        while elapsed < holdSeconds {
            sleep(2)
            wendy_kms_present(&display)
            elapsed += 2
        }

        wendy_kms_close(&display)
        print("closed; restored prior CRTC.")
    }
}
