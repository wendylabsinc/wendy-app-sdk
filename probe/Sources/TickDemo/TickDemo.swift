import WendyUI
import Foundation

/// Minimal SwiftCrossUI app exercising the live-update path of WendyKMSBackend:
/// a `.task` increments `@State` once a second, and each change must propagate
/// through the backend to a fresh scan-out frame on the device's display.
///
/// Requires the `gpu` entitlement to open `/dev/dri` — run with the gpu manifest
/// (e.g. `cp tickdemo.wendy.json wendy.json` before `wendy run --product TickDemo`).
@main
struct TickDemo: App {
    @State var count = 0

    var body: some Scene {
        WindowGroup("TickDemo") {
            VStack {
                Text("WendyKMSBackend tick demo")
                Text("count: \(count)")
            }
            .padding(40)
            .task {
                while true {
                    try? await Task.sleep(for: .seconds(1))
                    count += 1
                }
            }
        }
    }
}
