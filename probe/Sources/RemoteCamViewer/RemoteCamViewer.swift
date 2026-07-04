import Foundation
import WendyKMSDRM
import WendyCanvas
import WendyTextKit
import WendyKMSInput

#if canImport(Glibc)
    import Glibc
#elseif canImport(Darwin)
    import Darwin
#endif

// RemoteCam viewer — "Device A" in the two-device demo. Raw KMS display +
// evdev touch (same open sequence as KMSDrawProbe + WendyKMSInput's C API,
// no WendyUI/SwiftCrossUI in this target's dependency graph), with an
// on-screen Start/Stop button that dials a camera server on another WendyOS
// device over the mesh data plane and renders the FRAME_RGB frames it
// streams back. Protocol: probe/Sources/RemoteCamViewer/RemoteCamProtocol.swift
// (mirrors specs/remotecam-protocol.md).
//
// HARDWARE-VERIFIED on a Raspberry Pi 5 (KMS display + evdev touch + a real
// mesh dial to a camera server on a second device, both over LAN-direct
// mesh). macOS remains dev-only: `wendy_kms.c`/`wendy_input.c` ship macOS
// stub bodies (see their `#else` branches) purely so this target compiles
// there; the stubs make `wendy_kms_open`/`wendy_input_open` fail fast with
// ENOSYS rather than actually drawing or reading touch.
@main
struct RemoteCamViewer {
    static func main() {
        print("=== WendyOS RemoteCam viewer (Device A) ===")

        guard let peerID = ProcessInfo.processInfo.environment["REMOTE_DEVICE_ID"], !peerID.isEmpty else {
            print("REMOTE_DEVICE_ID is not set — expected Device B's asset ID (used to derive its mesh hostname)")
            exit(1)
        }
        let meshHost = "device-\(peerID).cloud.wendy.dev"
        let meshPort: UInt16 = 9090
        print("peer camera server: \(meshHost):\(meshPort)")

        let kmsPath = ProcessInfo.processInfo.environment["WENDY_KMS_DEVICE"] ?? "/dev/dri/card0"
        print("opening \(kmsPath) (stop sh.wendy.shell first so KMS is free)")

        var display = WendyKMSDisplay()
        var errBuf = [CChar](repeating: 0, count: 256)
        guard wendy_kms_open(kmsPath, &display, &errBuf, 256) == 0 else {
            let msg = errBuf.withUnsafeBytes { String(bytes: $0.prefix(while: { $0 != 0 }), encoding: .utf8) ?? "" }
            print("wendy_kms_open failed: \(msg)")
            exit(1)
        }
        guard let pixels = display.pixels else {
            print("no framebuffer mapped")
            wendy_kms_close(&display)
            exit(1)
        }
        let screenW = Int(display.width)
        let screenH = Int(display.height)
        let stride = Int(display.stride)
        print("display \(screenW)x\(screenH) stride=\(stride)")
        wendy_kms_flush_stdout()

        let canvas = Canvas(base: pixels, width: screenW, height: screenH, stride: stride)
        let font = FontFace.bundled()
        let ui = RemoteCamUI(canvas: canvas, font: font, screenWidth: screenW, screenHeight: screenH)
        let session = RemoteCamSession()

        var inputDevice = WendyInputDevice()
        var inputOpen = openTouchInput(&inputDevice)

        ui.drawChrome(state: .idle)
        wendy_kms_present(&display)
        wendy_kms_flush_stdout()
        print("ready; tap the button to start/stop the remote camera")
        wendy_kms_flush_stdout()

        // Tight poll loop (no framework run loop here, unlike WendyUI/
        // WendyKMSBackend apps): wendy_input_poll's fd is opened O_NONBLOCK
        // (see wendy_input.c), so this never blocks on touch. ~60 Hz keeps
        // taps feeling responsive without busy-spinning a core. The network
        // session runs on its own background Thread (RemoteCamSession) and
        // hands frames/state changes to this loop via drainUpdates(); no KMS
        // or Canvas calls ever happen off this thread.
        var touchRetryTicks = 0
        let touchRetryEveryTicks = 125 // ~2s at 16ms/tick, matching WendyKMSBackend's rescan cadence

        while true {
            if !inputOpen {
                touchRetryTicks += 1
                if touchRetryTicks >= touchRetryEveryTicks {
                    touchRetryTicks = 0
                    inputOpen = openTouchInput(&inputDevice)
                }
            } else {
                var raw = [WendyTouchEvent](repeating: WendyTouchEvent(), count: 32)
                let n = wendy_input_poll(&inputDevice, &raw, 32)
                if n < 0 {
                    print("touch device lost; will keep watching for it to return")
                    wendy_input_close(&inputDevice)
                    inputOpen = false
                } else if n > 0 {
                    for i in 0..<Int(n) {
                        // Spec: trigger directly on TOUCH_DOWN inside the
                        // button rect (no drag/tap-cancel gesture tracking —
                        // deliberately simple for this demo).
                        guard raw[i].kind == Int32(WENDY_TOUCH_DOWN.rawValue) else { continue }
                        let px = Int(raw[i].x * Float(screenW))
                        let py = Int(raw[i].y * Float(screenH))
                        if ui.buttonContains(x: px, y: py) {
                            handleButtonTap(session: session, host: meshHost, port: meshPort)
                        }
                    }
                }
            }

            for update in session.drainUpdates() {
                switch update {
                case .state(let s):
                    ui.drawChrome(state: s)
                    wendy_kms_present(&display)
                case .frame(let w, let h, let rgba):
                    ui.drawFrame(rgba, width: w, height: h)
                    wendy_kms_present(&display)
                }
            }

            usleep(16_000)
        }
    }
}

/// Attempts to open the touch device; logs and returns false (never fatal —
/// same "keep the display up without touch" philosophy as
/// WendyKMSBackend.setupTouchInput) if none is present yet.
private func openTouchInput(_ device: inout WendyInputDevice) -> Bool {
    var err = [CChar](repeating: 0, count: 1024)
    guard wendy_input_open(&device, &err, 1024) == 0 else {
        let msg = err.withUnsafeBytes { String(bytes: $0.prefix(while: { $0 != 0 }), encoding: .utf8) ?? "" }
        print("touch input unavailable, will keep retrying: \(msg)")
        return false
    }
    print("touch input active")
    return true
}

/// Not-connected -> dial the peer; connected (or mid-dial) -> stop. See
/// RemoteCamSession for how a stop requested mid-dial is latched so it isn't
/// lost.
private func handleButtonTap(session: RemoteCamSession, host: String, port: UInt16) {
    switch session.currentState {
    case .idle, .error:
        session.start(host: host, port: port)
    case .connecting, .streaming:
        session.stop()
    }
}
