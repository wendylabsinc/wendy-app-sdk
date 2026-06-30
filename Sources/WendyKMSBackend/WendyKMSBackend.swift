import Foundation
import Dispatch
import SwiftCrossUI
import WendyCanvas
import WendyKMSDRM

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

    public init() {}

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

    private func renderDirtyWindows() {
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
        defaultEnvironment
    }

    public func setRootEnvironmentChangeHandler(to action: @escaping @Sendable @MainActor () -> Void) {}

    // MARK: Windowing

    public func createWindow(withDefaultSize defaultSize: SIMD2<Int>?) -> KMSWindow {
        let window = KMSWindow()
        let path = ProcessInfo.processInfo.environment["WENDY_KMS_DEVICE"] ?? "/dev/dri/card0"
        var errBuf = [CChar](repeating: 0, count: 256)
        if wendy_kms_open(path, &window.display, &errBuf, 256) == 0, window.display.pixels != nil {
            window.isOpen = true
        } else {
            let msg = errBuf.withUnsafeBytes {
                String(bytes: $0.prefix(while: { $0 != 0 }), encoding: .utf8) ?? ""
            }
            print("WendyKMSBackend: wendy_kms_open failed: \(msg)")
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

    public func size(
        of text: String,
        whenDisplayedIn widget: KMSWidget,
        proposedWidth: Int?,
        proposedHeight: Int?,
        environment: EnvironmentValues
    ) -> SIMD2<Int> { .zero }

    public func createTextView() -> KMSWidget { KMSWidget(.text) }

    public func updateTextView(
        _ textView: KMSWidget,
        content: String,
        environment: EnvironmentValues
    ) {
        textView.text = content
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
        guard dataHasChanged else { return }
        imageView.rgba = rgbaData
        imageView.imgWidth = width
        imageView.imgHeight = height
        markAllDirty()
    }

    // MARK: Controls — Buttons

    public func createButton() -> KMSWidget { KMSWidget(.container) }

    public func updateButton(
        _ button: KMSWidget,
        label: String,
        environment: EnvironmentValues,
        action: @escaping () -> Void
    ) {}

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

    public func createScrollContainer(for child: KMSWidget) -> KMSWidget { KMSWidget(.container) }

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

    private func markAllDirty() {
        for w in windows { w.dirty = true }
    }
}
