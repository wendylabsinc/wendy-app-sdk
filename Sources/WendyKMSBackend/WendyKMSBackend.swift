import Foundation
import Dispatch
import SwiftCrossUI
import WendyCanvas
import WendyTextKit
import WendyKMSDRM
import WendyKMSInput

// LVGLBackend pattern: declare the typealias in the backend itself so that any
// module that imports WendyKMSBackend (directly or via WendyUI) automatically
// wires `App.Backend`. WendyUI re-exports this module on Linux; it does NOT
// redeclare the typealias to avoid a "redundant conformance" compiler error.
extension App {
    public typealias Backend = WendyKMSBackend

    /// Default backend instance. Mirrors the AppKitBackend / GtkBackend pattern:
    /// each App protocol extension provides a default `backend` so conforming
    /// types don't have to declare one explicitly.
    public var backend: WendyKMSBackend {
        WendyKMSBackend()
    }
}

public final class WendyKMSBackend: BaseAppBackend {
    public typealias Widget = KMSWidget
    public typealias Window = KMSWindow

    public var defaultPaddingAmount = 10
    public var deviceClass = DeviceClass.desktop
    public var supportsMultipleWindows = false
    public var canOverrideWindowColorScheme = false
    public var scrollBarWidth: Int { 0 }
    public var requiresImageUpdateOnScaleFactorChange = false
    public var requiresToggleSwitchSpacer = false
    public var supportedPickerStyles: [BackendPickerStyle] = [.menu]

    private var windows: [KMSWindow] = []
    private var renderTimer: DispatchSourceTimer?

    /// Cached to avoid re-parsing the embedded TTF on every text measurement/render.
    private static let sharedFont = FontFace.bundled()

    // Touch input (set up on first successful window open; nil off-device).
    var inputDevice = WendyInputDevice()
    var inputSource: DispatchSourceRead?
    var tapRecognizer = TapRecognizer(slop: 24)
    var pressedWidget: KMSWidget?
    let touchOrientation = TouchOrientation.fromEnvironment()

    public init() {}

    deinit {
        renderTimer?.cancel()
        inputSource?.cancel()
    }

    // MARK: Run loop

    public func runMainLoop(_ callback: @escaping @MainActor () -> Void) {
        callback()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(33))
        timer.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.renderDirtyWindows() }
        }
        timer.resume()
        renderTimer = timer
        dispatchMain()   // services the main queue (incl. @MainActor Tasks) + the timer
    }

    public nonisolated func runInMainThread(action: @escaping @MainActor () -> Void) {
        DispatchQueue.main.async { MainActor.assumeIsolated { action() } }
    }

    @MainActor private func renderDirtyWindows() {
        for window in windows where window.dirty && window.isOpen {
            guard let root = window.root, let pixels = window.display.pixels else { continue }
            let canvas = Canvas(
                base: pixels,
                width: Int(window.display.width),
                height: Int(window.display.height),
                stride: Int(window.display.stride)
            )
            // Clear to opaque black each frame, then paint the tree.
            canvas.fill(Color(r: 0, g: 0, b: 0))
            KMSRenderer.render(root, into: canvas, font: window.font)
            wendy_kms_present(&window.display)
            window.dirty = false
        }
    }

    // MARK: Environment

    public func computeRootEnvironment(defaultEnvironment: EnvironmentValues) -> EnvironmentValues {
        // renderDirtyWindows clears each frame to opaque black, so report a dark
        // color scheme. Otherwise SwiftCrossUI's default (.light) resolves
        // suggestedForegroundColor to .black — black text on a black framebuffer,
        // i.e. an invisible (apparently blank) screen.
        var env = defaultEnvironment
        env.colorScheme = .dark
        return env
    }

    public func setRootEnvironmentChangeHandler(to action: @escaping @Sendable @MainActor () -> Void) {}

    // MARK: Windowing

    public func createWindow(withDefaultSize defaultSize: SIMD2<Int>?) -> KMSWindow {
        let window = KMSWindow()
        let path = ProcessInfo.processInfo.environment["WENDY_KMS_DEVICE"] ?? "/dev/dri/card0"
        var errBuf = [CChar](repeating: 0, count: 256)
        if wendy_kms_open(path, &window.display, &errBuf, 256) == 0, window.display.pixels != nil {
            window.isOpen = true
            setupTouchInput(for: window)
        } else {
            let msg = errBuf.withUnsafeBytes {
                String(bytes: $0.prefix(while: { $0 != 0 }), encoding: .utf8) ?? ""
            }
            // Write to stderr (unbuffered) rather than print()'s block-buffered stdout:
            // when the device can't be opened (e.g. missing the `gpu` entitlement, or
            // another process holds DRM master) the process often exits before a buffered
            // stdout flush, hiding the one message that explains a blank screen.
            FileHandle.standardError.write(Data(
                "WendyKMSBackend: wendy_kms_open(\(path)) failed: \(msg)\n".utf8))
        }
        windows.append(window)
        return window
    }

    public func setChild(ofWindow window: KMSWindow, to child: KMSWidget) {
        window.root = child
        window.dirty = true
    }

    public func updateWindow(_ window: KMSWindow, environment: EnvironmentValues) {
        window.dirty = true
    }

    public func setTitle(ofWindow window: KMSWindow, to title: String) {}

    public func size(ofWindow window: KMSWindow) -> SIMD2<Int> {
        window.isOpen
            ? SIMD2(Int(window.display.width), Int(window.display.height))
            : defaultWindowSize
    }

    private let defaultWindowSize = SIMD2(1920, 1080)

    public func isWindowProgrammaticallyResizable(_ window: KMSWindow) -> Bool { false }

    public func setSize(ofWindow window: KMSWindow, to newSize: SIMD2<Int>) {}

    public func setSizeLimits(
        ofWindow window: KMSWindow,
        minimum minimumSize: SIMD2<Int>,
        maximum maximumSize: SIMD2<Int>?
    ) {}

    public func setResizeHandler(
        ofWindow window: KMSWindow,
        to action: @escaping (_ newSize: SIMD2<Int>) -> Void
    ) {}

    public func show(window: KMSWindow) { window.dirty = true }

    public func activate(window: KMSWindow) {}

    public func computeWindowEnvironment(
        window: KMSWindow,
        rootEnvironment: EnvironmentValues
    ) -> EnvironmentValues {
        rootEnvironment
    }

    public func setWindowEnvironmentChangeHandler(
        of window: KMSWindow,
        to action: @escaping @Sendable @MainActor () -> Void
    ) {}

    // MARK: Widgets

    public func show(widget: KMSWidget) {}

    public func showUpdate(of widget: KMSWidget) { markAllDirty() }

    public func naturalSize(of widget: KMSWidget) -> SIMD2<Int> {
        switch widget.kind {
        case .image: return SIMD2(widget.imgWidth, widget.imgHeight)
        case .button: return widget.naturalButtonSize
        default: return .zero
        }
    }

    public func setSize(of widget: KMSWidget, to size: SIMD2<Int>) {
        widget.size = size
        markAllDirty()
    }

    // MARK: Containers

    public func createContainer() -> KMSWidget { KMSWidget(.container) }

    public func removeAllChildren(of container: KMSWidget) {
        container.children.removeAll()
        markAllDirty()
    }

    public func insert(_ child: KMSWidget, into container: KMSWidget, at index: Int) {
        container.children.insert((child, .zero), at: index)
        markAllDirty()
    }

    public func swap(childAt i: Int, withChildAt j: Int, in container: KMSWidget) {
        container.children.swapAt(i, j)
        markAllDirty()
    }

    public func setPosition(ofChildAt index: Int, in container: KMSWidget, to position: SIMD2<Int>) {
        container.children[index].position = position
        markAllDirty()
    }

    public func remove(childAt index: Int, from container: KMSWidget) {
        container.children.remove(at: index)
        markAllDirty()
    }

    // MARK: PassiveViews — TextViews

    /// Global text-size multiplier for high-DPI panels (a 4K display makes the
    /// stock ~13pt body unreadably small). Override with `WENDY_KMS_FONT_SCALE`
    /// to tune without a rebuild.
    private lazy var fontScale: Float = {
        if let s = ProcessInfo.processInfo.environment["WENDY_KMS_FONT_SCALE"],
           let v = Float(s), v > 0 { return v }
        return 3.0
    }()

    /// `Font.resolve(in:)` is package-gated upstream, so the backend can't read a
    /// per-view `.font()`'s size directly. But `Font` is Equatable and the style
    /// statics are public, so we recover the text style by comparing against the
    /// known set and feed it to the backend's own `resolveTextStyle` — restoring
    /// real typographic hierarchy (largeTitle/title/headline/body/caption …).
    /// Anything unrecognised (e.g. a `.system(size:)` or emphasized font) falls
    /// back to body. MUST be used identically in `size(of:)` (measure) and
    /// `updateTextView` (render) or layout desyncs.
    private static let knownTextStyles: [(Font, Font.TextStyle)] = [
        (.largeTitle, .largeTitle), (.title, .title), (.title2, .title2), (.title3, .title3),
        (.headline, .headline), (.subheadline, .subheadline), (.body, .body),
        (.callout, .callout), (.caption, .caption), (.caption2, .caption2), (.footnote, .footnote),
    ]

    private func pxSize(for environment: EnvironmentValues) -> Float {
        let style = Self.knownTextStyles.first { $0.0 == environment.font }?.1 ?? .body
        return Float(resolveTextStyle(style).pointSize) * fontScale
    }

    public func size(
        of text: String,
        whenDisplayedIn widget: KMSWidget,
        proposedWidth: Int?,
        proposedHeight: Int?,
        environment: EnvironmentValues
    ) -> SIMD2<Int> {
        let m = Self.sharedFont.measure(text, pxSize: pxSize(for: environment))
        return SIMD2(Int(m.width.rounded(.up)), Int(m.height.rounded(.up)))
    }

    public func createTextView() -> KMSWidget { KMSWidget(.text) }

    public func updateTextView(
        _ textView: KMSWidget,
        content: String,
        environment: EnvironmentValues
    ) {
        textView.text = content
        textView.textPxSize = pxSize(for: environment)
        textView.textColor = WendyKMSBackend.toColor(
            environment.suggestedForegroundColor.resolve(in: environment)
        )
        markAllDirty()
    }

    // MARK: PassiveViews — Images

    public func createImageView() -> KMSWidget { KMSWidget(.image) }

    public func updateImageView(
        _ imageView: KMSWidget,
        rgbaData: [UInt8],
        width: Int,
        height: Int,
        targetWidth: Int,
        targetHeight: Int,
        dataHasChanged: Bool,
        environment: EnvironmentValues
    ) {
        _updateImageStorage(imageView, rgbaData: rgbaData, width: width, height: height,
                            dataHasChanged: dataHasChanged)
    }

    /// Stores image data on a widget. Extracted for testability without an EnvironmentValues.
    func _updateImageStorage(
        _ imageView: KMSWidget,
        rgbaData: [UInt8],
        width: Int,
        height: Int,
        dataHasChanged: Bool
    ) {
        if dataHasChanged { imageView.rgba = rgbaData }
        imageView.imgWidth = width
        imageView.imgHeight = height
        markAllDirty()
    }

    // MARK: Controls — Buttons

    public func createButton() -> KMSWidget { KMSWidget(.button) }

    public func updateButton(
        _ button: KMSWidget,
        label: String,
        environment: EnvironmentValues,
        action: @escaping () -> Void
    ) {
        _updateButtonStorage(
            button,
            label: label,
            pxSize: pxSize(for: environment),
            color: WendyKMSBackend.toColor(
                environment.suggestedForegroundColor.resolve(in: environment)),
            action: action
        )
    }

    /// Environment-free storage core so unit tests can drive it (EnvironmentValues
    /// has a package-gated init upstream — same pattern as _updateImageStorage).
    func _updateButtonStorage(
        _ button: KMSWidget,
        label: String,
        pxSize: Float,
        color: WendyCanvas.Color,
        action: @escaping () -> Void
    ) {
        button.label = label
        button.buttonPxSize = pxSize
        button.textColor = color
        button.action = action
        // Natural size = label measurement + padding proportional to the type
        // size (full em horizontally, half em vertically — split per side).
        let m = Self.sharedFont.measure(label, pxSize: pxSize)
        button.naturalButtonSize = SIMD2(
            Int(m.width.rounded(.up)) + Int(pxSize),
            Int(m.height.rounded(.up)) + Int(pxSize * 0.5)
        )
        markAllDirty()
    }

    // MARK: Controls — ToggleButtons

    public func createToggle() -> KMSWidget { KMSWidget(.container) }

    public func updateToggle(
        _ toggle: KMSWidget,
        label: String,
        environment: EnvironmentValues,
        onChange: @escaping (Bool) -> Void
    ) {}

    public func setState(ofToggle toggle: KMSWidget, to state: Bool) {}

    // MARK: Controls — Switches

    public func createSwitch() -> KMSWidget { KMSWidget(.container) }

    public func updateSwitch(
        _ switchWidget: KMSWidget,
        environment: EnvironmentValues,
        onChange: @escaping (Bool) -> Void
    ) {}

    public func setState(ofSwitch switchWidget: KMSWidget, to state: Bool) {}

    // MARK: Controls — Checkboxes

    public func createCheckbox() -> KMSWidget { KMSWidget(.container) }

    public func updateCheckbox(
        _ checkboxWidget: KMSWidget,
        environment: EnvironmentValues,
        onChange: @escaping (Bool) -> Void
    ) {}

    public func setState(ofCheckbox checkboxWidget: KMSWidget, to state: Bool) {}

    // MARK: Controls — Sliders

    public func createSlider() -> KMSWidget { KMSWidget(.container) }

    public func updateSlider(
        _ slider: KMSWidget,
        minimum: Double,
        maximum: Double,
        decimalPlaces: Int,
        environment: EnvironmentValues,
        onChange: @escaping (Double) -> Void
    ) {}

    public func setValue(ofSlider slider: KMSWidget, to value: Double) {}

    // MARK: Controls — TextFields

    public func createTextField() -> KMSWidget { KMSWidget(.container) }

    public func updateTextField(
        _ textField: KMSWidget,
        placeholder: String,
        environment: EnvironmentValues,
        onChange: @escaping (String) -> Void,
        onSubmit: @escaping () -> Void
    ) {}

    public func setContent(ofTextField textField: KMSWidget, to content: String) {}

    public func getContent(ofTextField textField: KMSWidget) -> String { "" }

    // MARK: Controls — SecureFields

    public func createSecureField() -> KMSWidget { KMSWidget(.container) }

    public func updateSecureField(
        _ secureField: KMSWidget,
        placeholder: String,
        environment: EnvironmentValues,
        onChange: @escaping (String) -> Void,
        onSubmit: @escaping () -> Void
    ) {}

    public func setContent(ofSecureField secureField: KMSWidget, to content: String) {}

    public func getContent(ofSecureField secureField: KMSWidget) -> String { "" }

    // MARK: Controls — TextEditors

    public func createTextEditor() -> KMSWidget { KMSWidget(.container) }

    public func updateTextEditor(
        _ textEditor: KMSWidget,
        environment: EnvironmentValues,
        onChange: @escaping (String) -> Void
    ) {}

    public func setContent(ofTextEditor textEditor: KMSWidget, to content: String) {}

    public func getContent(ofTextEditor textEditor: KMSWidget) -> String { "" }

    // MARK: Controls — Pickers

    public func createPicker(style: BackendPickerStyle) -> KMSWidget { KMSWidget(.container) }

    public func updatePicker(
        _ picker: KMSWidget,
        options: [String],
        environment: EnvironmentValues,
        onChange: @escaping (Int?) -> Void
    ) {}

    public func setSelectedOption(ofPicker picker: KMSWidget, to selectedOption: Int?) {}

    // MARK: Controls — ProgressBars

    public func createProgressBar() -> KMSWidget { KMSWidget(.container) }

    public func updateProgressBar(
        _ widget: KMSWidget,
        progressFraction: Double?,
        environment: EnvironmentValues
    ) {}

    // MARK: Controls — ProgressSpinners

    public func createProgressSpinner() -> KMSWidget { KMSWidget(.container) }

    // MARK: Containers — ScrollContainers

    public func createScrollContainer(for child: KMSWidget) -> KMSWidget {
        let c = KMSWidget(.container)
        c.children.append((child, SIMD2(0, 0)))
        return c
    }

    public func updateScrollContainer(
        _ scrollView: KMSWidget,
        environment: EnvironmentValues,
        bounceHorizontally: Bool,
        bounceVertically: Bool,
        hasHorizontalScrollBar: Bool,
        hasVerticalScrollBar: Bool
    ) {}

    // MARK: Containers — SelectableListViews

    public func createSelectableListView() -> KMSWidget { KMSWidget(.container) }

    public func updateSelectableListView(
        _ selectableListView: KMSWidget,
        environment: EnvironmentValues
    ) {}

    public func baseItemPadding(ofSelectableListView listView: KMSWidget) -> EdgeInsets {
        EdgeInsets(top: 0, bottom: 0, leading: 0, trailing: 0)
    }

    public func minimumRowSize(ofSelectableListView listView: KMSWidget) -> SIMD2<Int> { .zero }

    public func setItems(
        ofSelectableListView listView: KMSWidget,
        to items: [KMSWidget],
        withRowHeights rowHeights: [Int]
    ) {}

    public func setSelectionHandler(
        forSelectableListView listView: KMSWidget,
        to action: @escaping (Int) -> Void
    ) {}

    public func setSelectedItem(
        ofSelectableListView listView: KMSWidget,
        toItemAt index: Int?
    ) {}

    // MARK: Containers — SplitViews

    public func createSplitView(leadingChild: KMSWidget, trailingChild: KMSWidget) -> KMSWidget {
        KMSWidget(.container)
    }

    public func setResizeHandler(
        ofSplitView splitView: KMSWidget,
        to action: @escaping () -> Void
    ) {}

    public func sidebarWidth(ofSplitView splitView: KMSWidget) -> Int { 0 }

    public func setSidebarWidthBounds(
        ofSplitView splitView: KMSWidget,
        minimum minimumWidth: Int,
        maximum maximumWidth: Int
    ) {}

    // MARK: Helpers

    /// Mark all windows as needing redraw. Internal (not private) so the +Features.swift extension can call it.
    internal func markAllDirty() {
        for w in windows { w.dirty = true }
    }
}
