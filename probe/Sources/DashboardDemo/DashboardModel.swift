import WendyUI
import WendyKit

/// Live device state for the dashboard. A SwiftCrossUI `ObservableObject` (via
/// WendyUI's re-export) so the view re-renders when `@Published` fields change —
/// the same pattern HelloWendy uses. WendyKit throws on failure; the dashboard
/// decides the fallback (a short status string), it never fabricates data.
@MainActor
final class DashboardModel: ObservableObject {
    @Published var os = "…"
    @Published var agent = "…"
    @Published var wifi = "…"
    @Published var apps: [String] = []

    /// Resolved once: `fromEnvironment()` only reads `WENDY_AGENT_SOCKET`, and each
    /// RPC opens/closes its own connection, so there is nothing to keep alive.
    private let conn = WendyAgent.fromEnvironment()

    func refresh() async {
        guard let conn else {
            os = "no agent socket"
            return
        }
        if let v = try? await conn.deviceVersion() {
            os = "\(v.os) \(v.osVersion ?? "?")"
            agent = v.agentVersion
        }
        if let s = try? await conn.wifiStatus() {
            wifi = s.connected ? (s.ssid ?? "connected") : "offline"
        }
        if let a = try? await conn.apps() {
            apps = a.map { "\($0.appName) [\(Self.label($0.state))]" }
        }
    }

    private static func label(_ s: AppSummary.State) -> String {
        switch s {
        case .running: return "running"
        case .stopped: return "stopped"
        case .failed(let n): return "failed(\(n))"
        }
    }
}
