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

// MeshCounter: every device on the mesh runs this identical app, showing a
// shared running count. Tapping the screen increments the LOCAL count
// immediately (instant feedback) and broadcasts an INCREMENT message to
// every peer in MESH_PEERS; each peer applies the same +1 to its own count
// on receipt. Since every operation is "+1" (there is no decrement button in
// this demo), the message needs no payload at all — the message TYPE is the
// entire message, simpler than the spec's original "signed delta byte"
// while covering the exact same demo (YAGNI: nothing here ever sends
// anything other than +1). This is a pure-addition CRDT: commutative, so
// delivery order across different peers never matters and no conflict
// resolution is needed. Demonstrates mesh keeping simple shared state in
// sync across a fleet (contrast with MeshBeacon's transient, non-persisted
// broadcast).
//
// The display/touch stack below is identical to MeshBeacon's/RemoteCamViewer's,
// already proven on real hardware.

func log(_ message: String) {
    print("[meshcounter] \(message)")
}

/// The shared counter. `NSLock`-guarded since the mesh listener thread and
/// the main render/input loop both touch it — same hand-off shape as
/// MeshBeacon's `FlashState`.
final class CounterState: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    private var dirty = false

    func increment() {
        lock.lock()
        value += 1
        dirty = true
        lock.unlock()
    }

    /// Returns the current value if it changed since the last call
    /// (nil otherwise), so the render loop only redraws on an actual change.
    func snapshotIfDirty() -> Int? {
        lock.lock()
        defer { lock.unlock() }
        guard dirty else { return nil }
        dirty = false
        return value
    }
}

@main
struct MeshCounter {
    static func main() {
        let listenPort: UInt16 = 9092
        let incrementFrameType: UInt8 = 0x02

        let selfID = ProcessInfo.processInfo.environment["MESH_SELF"] ?? ""
        let peersRaw = ProcessInfo.processInfo.environment["MESH_PEERS"] ?? ""
        let peers = parseMeshPeers(peersRaw, excluding: selfID)

        log("self=\(selfID.isEmpty ? "(unset)" : selfID) peers=\(peers)")

        let counter = CounterState()

        let fanout = MeshFanout(peers: peers, listenPort: listenPort) { type, _ in
            guard type == incrementFrameType else { return }
            counter.increment()
        }

        do {
            try fanout.start()
            log("listening on port \(listenPort)")
        } catch {
            log("failed to start listener: \(error)")
            wendy_kms_flush_stdout()
            exit(1)
        }

        let kmsPath = ProcessInfo.processInfo.environment["WENDY_KMS_DEVICE"] ?? "/dev/dri/card0"
        log("opening \(kmsPath) (stop sh.wendy.shell first so KMS is free)")

        var display = WendyKMSDisplay()
        var errBuf = [CChar](repeating: 0, count: 256)
        guard wendy_kms_open(kmsPath, &display, &errBuf, 256) == 0 else {
            let msg = errBuf.withUnsafeBytes { String(bytes: $0.prefix(while: { $0 != 0 }), encoding: .utf8) ?? "" }
            log("wendy_kms_open failed: \(msg)")
            wendy_kms_flush_stdout()
            exit(1)
        }
        guard let pixels = display.pixels else {
            log("no framebuffer mapped")
            wendy_kms_close(&display)
            wendy_kms_flush_stdout()
            exit(1)
        }
        let screenW = Int(display.width)
        let screenH = Int(display.height)
        let stride = Int(display.stride)
        log("display \(screenW)x\(screenH) stride=\(stride)")
        wendy_kms_flush_stdout()

        let canvas = Canvas(base: pixels, width: screenW, height: screenH, stride: stride)
        let font = FontFace.bundled()
        let background = Color(r: 0x20, g: 0x20, b: 0x24)
        let textColor = Color(r: 0xE0, g: 0xE0, b: 0xE0)
        let hintColor = Color(r: 0x90, g: 0x90, b: 0x98)

        func draw(count: Int) {
            canvas.fill(background)
            canvas.drawText("\(count)", x: screenW / 2 - 80, baseline: screenH / 2, pxSize: 160, color: textColor, font: font)
            canvas.drawText(
                "tap anywhere for +1", x: 24, baseline: screenH - 48, pxSize: 28, color: hintColor, font: font)
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

        var currentCount = 0
        draw(count: currentCount)
        wendy_kms_present(&display)
        log("ready; tap anywhere for +1")
        wendy_kms_flush_stdout()

        var touchRetryTicks = 0
        let touchRetryEveryTicks = 125  // ~2s at 16ms/tick, matching RemoteCamViewer's rescan cadence

        func sendIncrement() {
            counter.increment()
            fanout.broadcast(type: incrementFrameType)
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
                        sendIncrement()
                    }
                }
            }

            if let newCount = counter.snapshotIfDirty() {
                currentCount = newCount
                draw(count: currentCount)
                wendy_kms_present(&display)
            }

            usleep(16_000)
        }
    }
}
