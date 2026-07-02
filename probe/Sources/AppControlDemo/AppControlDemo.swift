import WendyUI
import WendyKit

/// M4 touch demo: deployed apps with tap-to-start/stop, rendered by
/// WendyKMSBackend with evdev touch. Requires gpu (KMS) + admin (agent socket)
/// + input (/dev/input) — see appcontrol.wendy.json. Layout follows
/// DashboardDemo's conventions: the backend scales fonts ~3x for the 4K panel
/// but leaves layout at 1:1 px, so paddings/spacings are deliberately large.
@main
struct AppControlDemo: App {
    @State var model = AppControlModel()

    var body: some Scene {
        WindowGroup("Wendy App Control") {
            VStack(alignment: .leading, spacing: 36) {
                Text("App Control").font(.largeTitle).foregroundColor(Palette.accent)
                Text(model.status).font(.title3).foregroundColor(Palette.dim)
                Palette.edge.frame(maxWidth: .infinity).frame(height: 2)
                ForEach(model.rows) { row in
                    HStack(spacing: 40) {
                        Text("●").foregroundColor(Palette.status(row.state))
                        VStack(alignment: .leading, spacing: 8) {
                            Text(row.id).foregroundColor(Palette.primary)
                            Text("v\(row.version) · \(Palette.stateLabel(row.state))")
                                .font(.caption).foregroundColor(Palette.dim)
                        }
                        Spacer()
                        if row.busy {
                            Text("…").font(.title3).foregroundColor(Palette.dim)
                        } else if case .running = row.state {
                            Button("Stop") { model.toggle(row.id, state: row.state) }
                        } else {
                            Button("Start") { model.toggle(row.id, state: row.state) }
                        }
                    }
                    .padding(24)
                    .background(Palette.panel)
                }
                Spacer()
                Text("rendered by WendyKMSBackend · touch via evdev")
                    .font(.caption).foregroundColor(Palette.dim)
            }
            .padding(64)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .task {
                while !Task.isCancelled {
                    await model.refresh()
                    try? await Task.sleep(for: .seconds(2))
                }
            }
        }
    }
}

/// Trimmed copy of DashboardDemo's palette (separate executable target — the
/// probe package has no shared library target to host it, and 10 lines of
/// constants don't justify creating one).
enum Palette {
    static let accent  = Color(red: 0.31, green: 0.82, blue: 0.77)
    static let primary = Color(red: 0.93, green: 0.94, blue: 0.96)
    static let dim     = Color(red: 0.54, green: 0.58, blue: 0.64)
    static let panel   = Color(red: 0.086, green: 0.102, blue: 0.129)
    static let edge    = Color(red: 0.15, green: 0.17, blue: 0.22)
    static let green   = Color(red: 0.25, green: 0.73, blue: 0.31)
    static let gray    = Color(red: 0.43, green: 0.46, blue: 0.51)
    static let red     = Color(red: 0.97, green: 0.32, blue: 0.29)

    static func status(_ s: AppSummary.State) -> Color {
        switch s {
        case .running: return green
        case .stopped: return gray
        case .failed: return red
        }
    }

    static func stateLabel(_ s: AppSummary.State) -> String {
        switch s {
        case .running: return "running"
        case .stopped: return "stopped"
        case .failed(let n): return "failed (\(n))"
        }
    }
}
