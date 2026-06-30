import WendyUI
import WendyKit

/// M2 acceptance demo: a live WendyOS dashboard rendered by WendyKMSBackend over
/// the software DRM/KMS path. Pulls os/agent/wifi/app state from wendy-agent via
/// WendyKit every 2s; each refresh propagates through SwiftCrossUI to a fresh
/// scan-out frame. Requires `gpu` (open /dev/dri) + `admin` (agent socket) — see
/// dashboard.wendy.json.
///
/// Design note: the backend scales fonts ~3x for the 4K panel but leaves layout
/// at 1:1 px, so paddings/spacings here are deliberately large to stay in
/// proportion with the big type. Hierarchy comes from `.font(...)` (which the
/// backend now honours) plus colour, since the bundled face has a single weight.
@main
struct DashboardDemo: App {
    @State var model = DashboardModel()

    var body: some Scene {
        WindowGroup("WendyOS") {
            VStack(alignment: .leading, spacing: 36) {
                header
                Palette.edge.frame(maxWidth: .infinity).frame(height: 2)
                HStack(alignment: .top, spacing: 36) {
                    VStack(spacing: 36) {
                        systemCard
                        networkCard
                        Spacer()
                    }
                    .frame(width: 1320)
                    applicationsCard
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                Spacer()
                Text("wendyos-joannis.local   ·   rendered by WendyKMSBackend over SwiftCrossUI")
                    .font(.caption)
                    .foregroundColor(Palette.dim)
            }
            .padding(64)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .task {
                while true {
                    await model.refresh()
                    try? await Task.sleep(for: .seconds(2))
                }
            }
        }
    }

    // MARK: Sections

    var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 10) {
                Text("WendyOS").font(.largeTitle).foregroundColor(Palette.accent)
                Text("live device dashboard").font(.title3).foregroundColor(Palette.dim)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 10) {
                HStack(spacing: 16) {
                    (model.reachable ? Palette.green : Palette.gray).frame(width: 22, height: 22)
                    Text(model.reachable ? "LIVE" : "OFFLINE").foregroundColor(Palette.accent)
                }
                Text("updating every 2s").font(.caption).foregroundColor(Palette.dim)
            }
        }
    }

    var systemCard: some View {
        card("SYSTEM") {
            metric("OS", model.os, Palette.primary)
            metric("Agent", model.agent, Palette.primary)
            metric("Architecture", model.arch, Palette.primary)
            metric("GPU", model.gpu, model.gpuAvailable ? Palette.green : Palette.dim)
        }
    }

    var networkCard: some View {
        card("NETWORK") {
            HStack {
                (model.wifiOnline ? Palette.green : Palette.gray).frame(width: 22, height: 22)
                Text("Wi-Fi").foregroundColor(Palette.dim)
                Spacer()
                Text(model.wifi).foregroundColor(model.wifiOnline ? Palette.green : Palette.dim)
            }
        }
    }

    var applicationsCard: some View {
        card("APPLICATIONS") {
            if model.apps.isEmpty {
                Text("no containers").foregroundColor(Palette.dim)
            } else {
                ForEach(model.apps) { app in
                    HStack {
                        Palette.status(app.state).frame(width: 22, height: 22)
                        Text(app.name).foregroundColor(Palette.primary)
                        Spacer()
                        Text(Palette.stateLabel(app.state))
                            .font(.caption)
                            .foregroundColor(Palette.status(app.state))
                    }
                }
            }
            Spacer()
        }
    }

    // MARK: Building blocks

    func card<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 0) {
            Palette.accent.frame(width: 6)
            VStack(alignment: .leading, spacing: 36) {
                Text(title).font(.title3).foregroundColor(Palette.accent)
                content()
            }
            .padding(44)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Palette.panel)
    }

    func metric(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label).foregroundColor(Palette.dim)
            Spacer()
            Text(value).foregroundColor(color)
        }
    }
}

/// Dashboard colour palette (0…1 components).
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
