import WendyUI

/// M2 acceptance demo: a live WendyOS dashboard rendered by WendyKMSBackend over
/// the software DRM/KMS path. Pulls device state from wendy-agent via WendyKit
/// every few seconds; each refresh propagates through SwiftCrossUI to a fresh
/// scan-out frame. Requires both entitlements — `gpu` (open /dev/dri) and
/// `admin` (the agent socket) — see dashboard.wendy.json.
@main
struct DashboardDemo: App {
    @State var model = DashboardModel()

    var body: some Scene {
        WindowGroup("WendyOS") {
            VStack {
                Text("WendyOS — live dashboard").padding(.bottom, 16)
                Text("os: \(model.os)")
                Text("agent: \(model.agent)")
                Text("wifi: \(model.wifi)")
                Text("apps:")
                ForEach(model.apps, id: \.self) { row in
                    Text("  \(row)")
                }
            }
            .padding(48)
            .task {
                while true {
                    await model.refresh()
                    try? await Task.sleep(for: .seconds(2))
                }
            }
        }
    }
}
