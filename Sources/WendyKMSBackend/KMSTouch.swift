import Foundation
import Dispatch
import WendyKMSInput

/// Touch events in display-pixel space (after normalization + orientation).
enum TouchEvent: Equatable {
    case down(SIMD2<Int>)
    case move(SIMD2<Int>)
    case up(SIMD2<Int>)
}

/// Recognizes taps: an `up` whose entire contact stayed within `slop` px of its
/// `down`. `handle` returns the down-point when a tap completes, else nil.
/// Value type; no timing component (long-press is out of scope).
struct TapRecognizer {
    let slop: Int
    private var downPoint: SIMD2<Int>?
    private var cancelled = false

    init(slop: Int) { self.slop = slop }

    mutating func handle(_ event: TouchEvent) -> SIMD2<Int>? {
        switch event {
        case .down(let p):
            downPoint = p
            cancelled = false
            return nil
        case .move(let p):
            if let d = downPoint, !cancelled, exceedsSlop(p, d) { cancelled = true }
            return nil
        case .up(let p):
            defer { downPoint = nil }
            guard let d = downPoint, !cancelled, !exceedsSlop(p, d) else { return nil }
            return d
        }
    }

    private func exceedsSlop(_ a: SIMD2<Int>, _ b: SIMD2<Int>) -> Bool {
        let dx = a.x - b.x, dy = a.y - b.y
        return dx * dx + dy * dy > slop * slop
    }
}

/// Hit-testing over the retained KMSWidget tree. Positions are parent-relative
/// (as KMSRenderer paints them); later siblings paint later, i.e. on top, so
/// they win overlaps. Only widgets with a non-nil `action` are hittable —
/// everything else is transparent to touches.
enum KMSHitTest {
    static func actionTarget(in root: KMSWidget, at point: SIMD2<Int>) -> KMSWidget? {
        target(in: root, origin: .zero, point: point)
    }

    private static func target(
        in widget: KMSWidget, origin: SIMD2<Int>, point: SIMD2<Int>
    ) -> KMSWidget? {
        for child in widget.children.reversed() {
            if let hit = target(in: child.widget, origin: origin &+ child.position, point: point) {
                return hit
            }
        }
        guard widget.action != nil,
              point.x >= origin.x, point.y >= origin.y,
              point.x < origin.x + widget.size.x, point.y < origin.y + widget.size.y
        else { return nil }
        return widget
    }
}

/// Maps the shim's normalized (0…1) coordinates to display pixels, with env
/// overrides for panels whose touch matrix is rotated/mirrored relative to the
/// framebuffer: WENDY_TOUCH_SWAP_XY, WENDY_TOUCH_INVERT_X, WENDY_TOUCH_INVERT_Y
/// (set to "1" to enable).
struct TouchOrientation {
    let swapXY: Bool
    let invertX: Bool
    let invertY: Bool

    static func fromEnvironment() -> TouchOrientation {
        func flag(_ name: String) -> Bool {
            ProcessInfo.processInfo.environment[name] == "1"
        }
        return TouchOrientation(
            swapXY: flag("WENDY_TOUCH_SWAP_XY"),
            invertX: flag("WENDY_TOUCH_INVERT_X"),
            invertY: flag("WENDY_TOUCH_INVERT_Y")
        )
    }

    func pixelPoint(nx: Float, ny: Float, width: Int, height: Int) -> SIMD2<Int> {
        var x = swapXY ? ny : nx
        var y = swapXY ? nx : ny
        if invertX { x = 1 - x }
        if invertY { y = 1 - y }
        return SIMD2(
            min(width - 1, max(0, Int(x * Float(width)))),
            min(height - 1, max(0, Int(y * Float(height))))
        )
    }
}

extension WendyKMSBackend {
    /// Attempts to open the touch device and attach a main-queue read source.
    /// First called from `createWindow`; if no touch device is present it starts
    /// a rescan timer and keeps trying, so a touchscreen plugged in (or replugged)
    /// after launch is picked up without restarting the app. Missing hardware is
    /// never an error — the app stays display-only until one appears.
    @MainActor func setupTouchInput(for window: KMSWindow) {
        guard inputSource == nil else { return }
        var err = [CChar](repeating: 0, count: 1024)
        guard wendy_input_open(&inputDevice, &err, 1024) == 0 else {
            if !touchUnavailableLogged {
                touchUnavailableLogged = true
                let msg = err.withUnsafeBytes {
                    String(bytes: $0.prefix(while: { $0 != 0 }), encoding: .utf8) ?? ""
                }
                FileHandle.standardError.write(Data(
                    "WendyKMSBackend: touch input unavailable (display-only), will keep watching for a device: \(msg)\n".utf8))
            }
            startTouchRetry(for: window)
            return
        }
        stopTouchRetry()
        touchUnavailableLogged = false
        // ~24 px slop at 1080p, scaled with the panel.
        tapRecognizer = TapRecognizer(slop: max(8, Int(window.display.height) / 45))
        let source = DispatchSource.makeReadSource(
            fileDescriptor: wendy_input_fd(&inputDevice), queue: .main)
        source.setEventHandler { [weak self, weak window] in
            guard let self, let window else { return }
            MainActor.assumeIsolated { self.drainTouchEvents(window: window) }
        }
        source.setCancelHandler { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated { wendy_input_close(&self.inputDevice) }
        }
        source.resume()
        inputSource = source
        FileHandle.standardError.write(Data("WendyKMSBackend: touch input active\n".utf8))
    }

    /// Rescan for a touch device every 2s until one is acquired. Cheap (a handful
    /// of open()+ioctl on /dev/input/event*), idempotent, and self-stopping:
    /// setupTouchInput calls stopTouchRetry once it succeeds.
    @MainActor func startTouchRetry(for window: KMSWindow) {
        guard touchRetryTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .seconds(2), repeating: .seconds(2))
        timer.setEventHandler { [weak self, weak window] in
            guard let self, let window else { return }
            MainActor.assumeIsolated {
                if self.inputSource == nil { self.setupTouchInput(for: window) }
                else { self.stopTouchRetry() }
            }
        }
        timer.resume()
        touchRetryTimer = timer
    }

    @MainActor func stopTouchRetry() {
        touchRetryTimer?.cancel()
        touchRetryTimer = nil
    }

    @MainActor func drainTouchEvents(window: KMSWindow) {
        var raw = [WendyTouchEvent](repeating: WendyTouchEvent(), count: 64)
        while true {
            let n = Int(wendy_input_poll(&inputDevice, &raw, 64))
            if n < 0 {
                // Device gone (unplugged / re-enumerated). Tear down the source and
                // resume rescanning so it is re-acquired when it comes back — no
                // restart needed. The cancel handler closes the fd.
                FileHandle.standardError.write(Data(
                    "WendyKMSBackend: touch device lost; watching for it to return\n".utf8))
                inputSource?.cancel()
                inputSource = nil
                touchUnavailableLogged = true   // already know it's gone; don't re-log
                if let w = pressedWidget {
                    w.pressed = false
                    markAllDirty()
                    pressedWidget = nil
                }
                startTouchRetry(for: window)
                return
            }
            if n == 0 { return }
            for i in 0..<n {
                let p = touchOrientation.pixelPoint(
                    nx: raw[i].x, ny: raw[i].y,
                    width: Int(window.display.width), height: Int(window.display.height))
                let event: TouchEvent
                switch raw[i].kind {
                case Int32(WENDY_TOUCH_DOWN.rawValue): event = .down(p)
                case Int32(WENDY_TOUCH_UP.rawValue):   event = .up(p)
                default:                                event = .move(p)
                }
                if let root = window.root { handleTouch(event, root: root) }
            }
            if n < 64 { return }
        }
    }

    /// The testable dispatch core: pressed-state bookkeeping + tap → action.
    @MainActor func handleTouch(_ event: TouchEvent, root: KMSWidget) {
        if case .down(let p) = event {
            pressedWidget = KMSHitTest.actionTarget(in: root, at: p)
            if let w = pressedWidget {
                w.pressed = true
                markAllDirty()
            }
        }
        let tap = tapRecognizer.handle(event)
        if case .up = event {
            if let w = pressedWidget {
                w.pressed = false
                markAllDirty()
            }
            // A tap always reports the down-point, so the recognized target is
            // exactly the widget pressed on down.
            if tap != nil { pressedWidget?.action?() }
            pressedWidget = nil
        }
    }
}
