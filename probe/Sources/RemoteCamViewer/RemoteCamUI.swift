import WendyCanvas
import WendyTextKit

/// Layout + drawing for the viewer's two regions: a fixed top-strip
/// Start/Stop button and a video panel below it that shows placeholder text
/// until a frame arrives. All coordinates are device pixels.
final class RemoteCamUI {
    let buttonRect: (x: Int, y: Int, w: Int, h: Int)
    let videoPanel: (x: Int, y: Int, w: Int, h: Int)

    private let canvas: Canvas
    private let font: FontFace

    private static let background = Color(r: 0x10, g: 0x14, b: 0x20)
    private static let panelBg = Color(r: 0x08, g: 0x0A, b: 0x12)
    private static let buttonIdle = Color(r: 0x21, g: 0xD0, b: 0xC0)
    private static let buttonLive = Color(r: 0xE0, g: 0x3B, b: 0x3B)
    private static let textDim = Color(r: 0x8A, g: 0x92, b: 0xA0)

    init(canvas: Canvas, font: FontFace, screenWidth: Int, screenHeight: Int) {
        self.canvas = canvas
        self.font = font
        self.buttonRect = (x: 40, y: 30, w: 260, h: 90)
        // Below the button strip, filling the rest of the screen (min-clamped
        // so layout stays sane even on a very small panel).
        self.videoPanel = (
            x: 40, y: 150,
            w: max(0, screenWidth - 80),
            h: max(0, screenHeight - 190)
        )
    }

    /// Hit-test in display-pixel space (touch coordinates are denormalized by
    /// the caller: `x = nx * screenWidth`, `y = ny * screenHeight`).
    func buttonContains(x: Int, y: Int) -> Bool {
        x >= buttonRect.x && x < buttonRect.x + buttonRect.w
            && y >= buttonRect.y && y < buttonRect.y + buttonRect.h
    }

    /// Full chrome redraw (background + button + video panel). Call once at
    /// startup and again whenever the session's state changes. While
    /// `.streaming`, the panel is left blank (no placeholder text) because a
    /// `.frame` update — drawn separately via `drawFrame` — is expected
    /// imminently and would otherwise flash text between frames.
    func drawChrome(state: RemoteCamSession.State) {
        canvas.fill(Self.background)
        drawButton(state: state)
        canvas.fillRect(x: videoPanel.x, y: videoPanel.y, w: videoPanel.w, h: videoPanel.h, Self.panelBg)
        if case .streaming = state {} else {
            drawPlaceholder(for: state)
        }
    }

    /// Blits one already-RGBA-padded camera frame at the video panel's
    /// top-left, at native resolution — `Canvas.blitImage` has no scaling, so
    /// a frame smaller than the panel (e.g. the protocol's fixed 320x240)
    /// simply leaves the panel's background showing around it.
    func drawFrame(_ rgba: [UInt8], width: Int, height: Int) {
        canvas.blitImage(rgba, width: width, height: height, x: videoPanel.x, y: videoPanel.y)
    }

    private func drawButton(state: RemoteCamSession.State) {
        let label: String
        let color: Color
        switch state {
        case .idle, .error:
            label = "Start"
            color = Self.buttonIdle
        case .connecting:
            label = "Connecting…"
            color = Self.buttonLive
        case .streaming:
            label = "Stop"
            color = Self.buttonLive
        }
        canvas.fillRect(x: buttonRect.x, y: buttonRect.y, w: buttonRect.w, h: buttonRect.h, color)
        canvas.drawText(
            label, x: buttonRect.x + 24, baseline: buttonRect.y + buttonRect.h - 32,
            pxSize: 32, color: Self.background, font: font)
    }

    private func drawPlaceholder(for state: RemoteCamSession.State) {
        let message: String
        switch state {
        case .idle: message = "Tap Start to view the remote camera"
        case .connecting: message = "Connecting to peer…"
        case .error(let reason): message = "Error: \(reason) — tap Start to retry"
        case .streaming: message = "" // unreachable; drawChrome skips this branch for .streaming
        }
        canvas.drawText(
            message, x: videoPanel.x + 24, baseline: videoPanel.y + videoPanel.h / 2,
            pxSize: 28, color: Self.textDim, font: font)
    }
}
