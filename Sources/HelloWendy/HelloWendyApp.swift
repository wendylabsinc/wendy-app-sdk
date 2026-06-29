import WendyUI
import WendyKit

@main
struct HelloWendyApp: App {
    // On-device the admin entitlement provides WENDY_AGENT_SOCKET; in dev without
    // it, fall back to a sample provider so the window still renders.
    @State var model = DeviceStatusModel(
        provider: WendyAgent.fromEnvironment() ?? SampleProvider()
    )

    var body: some Scene {
        WindowGroup("HelloWendy") {
            VStack {
                Text("HelloWendy")
                Text(model.line)
                ForEach(model.apps, id: \.id) { app in
                    Text("\(app.appName) — \(label(for: app.state))")
                }
                Button("Refresh") {
                    Task { await model.load() }
                }
            }
            .padding(20)
            .task {
                await model.load()
            }
        }
    }

    func label(for state: AppSummary.State) -> String {
        switch state {
        case .running: return "running"
        case .stopped: return "stopped"
        case .failed(let n): return "failed (\(n))"
        }
    }
}

/// Dev fallback when no agent socket is present (running on a plain Mac).
struct SampleProvider: DeviceStatusProviding {
    func deviceVersion() async throws -> DeviceVersion {
        DeviceVersion(agentVersion: "dev", os: "macOS", osVersion: nil,
                      cpuArchitecture: "arm64", deviceType: nil, hasGPU: false)
    }
    func apps() async throws -> [AppSummary] {
        [AppSummary(appName: "com.example.sample", appVersion: "0.0.1", state: .stopped)]
    }
}
