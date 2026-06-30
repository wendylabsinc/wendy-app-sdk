import WendyUI
import WendyKit

/// Live device state for the dashboard. A SwiftCrossUI `ObservableObject` (via
/// WendyUI's re-export) so the view re-renders when `@Published` fields change —
/// the same pattern HelloWendy uses. WendyKit throws on failure; the dashboard
/// shows a short status string rather than fabricating data.
@MainActor
final class DashboardModel: ObservableObject {
    struct AppRow: Identifiable, Equatable {
        let id: String
        let name: String
        let state: AppSummary.State
    }

    @Published var os = "—"
    @Published var agent = "—"
    @Published var arch = "—"
    @Published var wifi = "—"
    @Published var wifiOnline = false
    @Published var apps: [AppRow] = []
    @Published var reachable = false

    // Live utilisation (read from the device kernel interfaces, not WendyKit).
    @Published var cpu: Int?
    @Published var cpuDetail = "—"
    @Published var mem: Int?
    @Published var memDetail = "—"
    @Published var gpu: Int?
    @Published var gpuDetail = "—"

    /// Resolved once: `fromEnvironment()` only reads `WENDY_AGENT_SOCKET`, and each
    /// RPC opens/closes its own connection, so there is nothing to keep alive.
    private let conn = WendyAgent.fromEnvironment()
    private let metrics = SystemMetrics()

    func refresh() async {
        let s = metrics.read()
        cpu = s.cpuPercent; cpuDetail = s.cpuDetail
        mem = s.memPercent; memDetail = s.memDetail
        gpu = s.gpuPercent; gpuDetail = s.gpuDetail

        guard let conn else {
            os = "no agent socket"
            reachable = false
            return
        }
        if let v = try? await conn.deviceVersion() {
            os = "\(v.os) \(v.osVersion ?? "?")"
            agent = v.agentVersion
            arch = v.cpuArchitecture
            reachable = true
        }
        if let s = try? await conn.wifiStatus() {
            wifiOnline = s.connected
            wifi = s.connected ? (s.ssid ?? "connected") : "offline"
        }
        if let a = try? await conn.apps() {
            apps = a.map { AppRow(id: $0.appName, name: $0.appName, state: $0.state) }
        }
    }
}
