import WendyUI
import WendyKit

/// App list + start/stop actions for the touch demo. Same ObservableObject
/// pattern as DashboardModel. Rows the demo must not control are filtered out:
/// itself (tapping Stop on yourself kills the screen) and the shell (stopped
/// by the operator to free KMS; restarting it would steal the display).
@MainActor
final class AppControlModel: ObservableObject {
    struct Row: Identifiable, Equatable {
        let id: String        // appName
        let version: String
        let state: AppSummary.State
        let busy: Bool        // an RPC is in flight; button disabled
    }

    static let ownAppId = "sh.wendy.app-sdk-appcontrol"
    static let hidden: Set<String> = [ownAppId, "sh.wendy.shell"]

    @Published var rows: [Row] = []
    @Published var status = "connecting…"

    private let conn = WendyAgent.fromEnvironment()
    private var busyApps: Set<String> = []

    func refresh() async {
        guard let conn else {
            status = "no agent socket (admin entitlement?)"
            return
        }
        do {
            let apps = try await conn.apps()
            rows = apps
                .filter { !Self.hidden.contains($0.appName) }
                .map {
                    Row(id: $0.appName, version: $0.appVersion,
                        state: $0.state, busy: busyApps.contains($0.appName))
                }
            status = rows.isEmpty ? "no controllable apps deployed" : "tap a button to start/stop"
        } catch {
            status = "agent error: \(error)"
        }
    }

    /// Start or stop `appName` depending on its current state, then re-fetch.
    /// Re-entrancy guard: taps while busy are ignored.
    func toggle(_ appName: String, state: AppSummary.State) {
        guard let conn, !busyApps.contains(appName) else { return }
        busyApps.insert(appName)
        markBusy(appName, true)
        Task {
            do {
                if case .running = state {
                    try await conn.stopApp(named: appName)
                } else {
                    try await conn.startApp(named: appName)
                }
            } catch {
                status = "\(appName): \(error)"
            }
            busyApps.remove(appName)
            await refresh()
        }
    }

    private func markBusy(_ appName: String, _ busy: Bool) {
        rows = rows.map {
            $0.id == appName
                ? Row(id: $0.id, version: $0.version, state: $0.state, busy: busy)
                : $0
        }
    }
}
