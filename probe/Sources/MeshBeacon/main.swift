import Foundation
import WendyKMSDRM
import WendyCanvas
import WendyTextKit
import WendyKMSInput
import MeshFanout

#if canImport(Glibc)
    import Glibc
#elseif canImport(Darwin)
    import Darwin
#endif

// MeshBeacon: every device on the mesh runs this identical app. Tapping
// anywhere on the screen broadcasts a "beacon" (this device's own color) to
// every peer in MESH_PEERS; every device that receives one — including the
// sender itself, via an immediate local flash — fills its screen with that
// color for one second. Demonstrates one-to-many pub/sub fan-out over the
// mesh data plane (contrast with RemoteCam's 1:1 unicast stream).
//
// The display/touch stack below is the same one RemoteCamViewer already
// proved on real hardware (wendy-app-sdk/probe/Sources/RemoteCamViewer); the
// MeshFanout networking is new but built on the exact dial/frame primitives
// RemoteCamViewer's own RemoteCamProtocol.swift already proved.

extension Color {
    var r: UInt8 { UInt8((value >> 16) & 0xFF) }
    var g: UInt8 { UInt8((value >> 8) & 0xFF) }
    var b: UInt8 { UInt8(value & 0xFF) }
}

let palette: [Color] = [
    Color(r: 0xE5, g: 0x3E, b: 0x3E),  // red
    Color(r: 0x3E, g: 0x7A, b: 0xE5),  // blue
    Color(r: 0x3E, g: 0xC9, b: 0x5D),  // green
    Color(r: 0xE5, g: 0xC4, b: 0x3E),  // yellow
    Color(r: 0xB0, g: 0x3E, b: 0xE5),  // purple
    Color(r: 0xE5, g: 0x8A, b: 0x3E),  // orange
]

func log(_ message: String) {
    print("[meshbeacon] \(message)")
}

/// Shared between the mesh listener thread and the main render/input loop:
/// the listener only ever writes `pending`, the main loop only ever
/// reads-and-clears it via `takePending` — guarded by a lock since they run
/// on different threads, the same hand-off shape RemoteCamSession uses for
/// its own background-thread-to-main-loop updates.
final class FlashState: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: Color?

    func setPending(_ color: Color) {
        lock.lock()
        pending = color
        lock.unlock()
    }

    func takePending() -> Color? {
        lock.lock()
        defer { lock.unlock() }
        let value = pending
        pending = nil
        return value
    }
}

@main
struct MeshBeacon {
    static func main() {
        let listenPort: UInt16 = 9091
        let beaconFlashDuration: TimeInterval = 1.0
        let beaconFrameType: UInt8 = 0x01

        let selfID = ProcessInfo.processInfo.environment["MESH_SELF"] ?? ""
        let peersRaw = ProcessInfo.processInfo.environment["MESH_PEERS"] ?? ""
        let peers = parseMeshPeers(peersRaw, excluding: selfID)
        let selfColor = palette[stablePaletteIndex(for: selfID, paletteSize: palette.count)]

        log("self=\(selfID.isEmpty ? "(unset)" : selfID) peers=\(peers)")

        let flashState = FlashState()

        let fanout = MeshFanout(peers: peers, listenPort: listenPort) { type, payload in
            guard type == beaconFrameType, payload.count == 3 else { return }
            flashState.setPending(Color(r: payload[0], g: payload[1], b: payload[2]))
        }

        do {
            try fanout.start()
            log("listening on port \(listenPort)")
        } catch {
            log("failed to start listener: \(error)")
            exit(1)
        }

        let kmsPath = ProcessInfo.processInfo.environment["WENDY_KMS_DEVICE"] ?? "/dev/dri/card0"
        log("opening \(kmsPath) (stop sh.wendy.shell first so KMS is free)")

        var display = WendyKMSDisplay()
        var errBuf = [CChar](repeating: 0, count: 256)
        guard wendy_kms_open(kmsPath, &display, &errBuf, 256) == 0 else {
            let msg = errBuf.withUnsafeBytes { String(bytes: $0.prefix(while: { $0 != 0 }), encoding: .utf8) ?? "" }
            log("wendy_kms_open failed: \(msg)")
            exit(1)
        }
        guard let pixels = display.pixels else {
            log("no framebuffer mapped")
            wendy_kms_close(&display)
            exit(1)
        }
        let screenW = Int(display.width)
        let screenH = Int(display.height)
        let stride = Int(display.stride)
        log("display \(screenW)x\(screenH) stride=\(stride)")
        wendy_kms_flush_stdout()

        let canvas = Canvas(base: pixels, width: screenW, height: screenH, stride: stride)
        let font = FontFace.bundled()
        let idleBackground = Color(r: 0x20, g: 0x20, b: 0x24)
        let hintColor = Color(r: 0xE0, g: 0xE0, b: 0xE0)

        func drawIdle() {
            canvas.fill(idleBackground)
            canvas.fillRect(x: 24, y: 24, w: 48, h: 48, selfColor)  // this device's own color swatch
            canvas.drawText(
                "tap anywhere to send a beacon", x: 24, baseline: screenH / 2, pxSize: 32, color: hintColor, font: font)
        }

        var inputDevice = WendyInputDevice()
        var inputOpen: Bool = {
            var err = [CChar](repeating: 0, count: 1024)
            guard wendy_input_open(&inputDevice, &err, 1024) == 0 else {
                let msg = err.withUnsafeBytes { String(bytes: $0.prefix(while: { $0 != 0 }), encoding: .utf8) ?? "" }
                log("touch input unavailable, will keep retrying: \(msg)")
                return false
            }
            log("touch input active")
            return true
        }()

        drawIdle()
        wendy_kms_present(&display)
        log("ready; tap anywhere to send a beacon")
        wendy_kms_flush_stdout()

        var flashUntil: Date?
        var touchRetryTicks = 0
        let touchRetryEveryTicks = 125  // ~2s at 16ms/tick, matching RemoteCamViewer's rescan cadence

        func sendBeacon() {
            log("sending beacon (color=0x\(String(selfColor.value, radix: 16)))")
            fanout.broadcast(type: beaconFrameType, payload: [selfColor.r, selfColor.g, selfColor.b])
            flashState.setPending(selfColor)  // immediate local feedback; don't wait on the network
        }

        while true {
            if !inputOpen {
                touchRetryTicks += 1
                if touchRetryTicks >= touchRetryEveryTicks {
                    touchRetryTicks = 0
                    var err = [CChar](repeating: 0, count: 1024)
                    inputOpen = wendy_input_open(&inputDevice, &err, 1024) == 0
                    if inputOpen { log("touch input active") }
                }
            } else {
                var raw = [WendyTouchEvent](repeating: WendyTouchEvent(), count: 32)
                let n = wendy_input_poll(&inputDevice, &raw, 32)
                if n < 0 {
                    log("touch device lost; will keep watching for it to return")
                    wendy_input_close(&inputDevice)
                    inputOpen = false
                } else if n > 0 {
                    for i in 0..<Int(n) where raw[i].kind == Int32(WENDY_TOUCH_DOWN.rawValue) {
                        sendBeacon()
                    }
                }
            }

            if let color = flashState.takePending() {
                canvas.fill(color)
                wendy_kms_present(&display)
                flashUntil = Date().addingTimeInterval(beaconFlashDuration)
            } else if let until = flashUntil, Date() >= until {
                flashUntil = nil
                drawIdle()
                wendy_kms_present(&display)
            }

            usleep(16_000)
        }
    }
}
