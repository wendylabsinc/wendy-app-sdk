import WendyUI
import WendyKit

/// M2 acceptance demo: a live WendyOS dashboard rendered by WendyKMSBackend over
/// the software DRM/KMS path. Pulls os/agent/wifi/app state from wendy-agent via
/// WendyKit and CPU/memory/GPU utilisation from the device kernel interfaces,
/// every 2s; each refresh propagates through SwiftCrossUI to a fresh scan-out
/// frame. Requires `gpu` (open /dev/dri) + `admin` (agent socket) — see
/// dashboard.wendy.json.
///
/// Design note: the backend scales fonts ~3x for the 4K panel but leaves layout
/// at 1:1 px, so paddings/spacings/widths here are deliberately large to stay in
/// proportion with the big type. Hierarchy comes from `.font(...)` (which the
/// backend honours) plus colour; the bundled face has a single weight. Status is
/// shown with a `●` glyph (a real circle via the text path) rather than a square.
@main
struct DashboardDemo: App {
    @State var model = DashboardModel()

    // Fixed-resolution layout (device mode is 3840x2160). Root padding 64 →
    // content 3712: three gauge tiles + two gaps, then a 1320 column + the rest.
    static let tileWidth = 1210
    static let barWidth = tileWidth - 6 - 2 * 44   // tile − accent rail − padding
    static let leftColumn = 1320

    var body: some Scene {
        WindowGroup("WendyOS") {
            VStack(alignment: .leading, spacing: 36) {
                header
                Palette.edge.frame(maxWidth: .infinity).frame(height: 2)
                HStack(spacing: 40) {
                    gaugeTile("CPU", model.cpu, model.cpuDetail)
                    gaugeTile("MEMORY", model.mem, model.memDetail)
                    gaugeTile("GPU", model.gpu, model.gpuDetail)
                }
                HStack(alignment: .top, spacing: 40) {
                    VStack(spacing: 40) {
                        systemCard
                        networkCard
                        Spacer()
                    }
                    .frame(width: Double(Self.leftColumn))
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
                HStack(spacing: 14) {
                    dot(model.reachable ? Palette.green : Palette.gray)
                    Text(model.reachable ? "LIVE" : "OFFLINE").foregroundColor(Palette.accent)
                }
                Text("updating every 2s").font(.caption).foregroundColor(Palette.dim)
            }
        }
    }

    func gaugeTile(_ title: String, _ pct: Int?, _ detail: String) -> some View {
        railCard {
            Text(title).font(.title3).foregroundColor(Palette.dim)
            HStack(alignment: .bottom, spacing: 10) {
                Text(pct.map(String.init) ?? "—").font(.largeTitle).foregroundColor(Palette.primary)
                if pct != nil { Text("%").font(.title3).foregroundColor(Palette.dim) }
                Spacer()
                Text(detail).font(.caption).foregroundColor(Palette.dim)
            }
            bar(pct ?? 0)
        }
        .frame(width: Double(Self.tileWidth))
    }

    var systemCard: some View {
        railCard {
            Text("SYSTEM").font(.title3).foregroundColor(Palette.dim)
            metric("OS", model.os, Palette.primary)
            metric("Agent", model.agent, Palette.primary)
            metric("Architecture", model.arch, Palette.primary)
        }
    }

    var networkCard: some View {
        railCard {
            Text("NETWORK").font(.title3).foregroundColor(Palette.dim)
            HStack {
                dot(model.wifiOnline ? Palette.green : Palette.gray)
                Text("Wi-Fi").foregroundColor(Palette.dim)
                Spacer()
                Text(model.wifi).foregroundColor(model.wifiOnline ? Palette.green : Palette.dim)
            }
        }
    }

    var applicationsCard: some View {
        railCard {
            Text("APPLICATIONS").font(.title3).foregroundColor(Palette.dim)
            if model.apps.isEmpty {
                Text("no containers").foregroundColor(Palette.dim)
            } else {
                ForEach(model.apps) { app in
                    HStack {
                        dot(Palette.status(app.state))
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

    /// A panel with an accent left rail and generous padding.
    func railCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 0) {
            Palette.accent.frame(width: 6)
            VStack(alignment: .leading, spacing: 32) {
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

    /// Horizontal usage bar: a track with a proportional coloured fill.
    func bar(_ pct: Int) -> some View {
        ZStack(alignment: .leading) {
            Palette.track.frame(width: Double(Self.barWidth), height: 24)
            Palette.load(pct).frame(width: Double(Self.barWidth * max(0, min(100, pct)) / 100), height: 24)
        }
    }

    /// A round status indicator (real circle via the font's ● glyph).
    func dot(_ color: Color) -> some View {
        Text("●").foregroundColor(color)
    }
}

/// Dashboard colour palette (0…1 components).
enum Palette {
    static let accent  = Color(red: 0.31, green: 0.82, blue: 0.77)
    static let primary = Color(red: 0.93, green: 0.94, blue: 0.96)
    static let dim     = Color(red: 0.54, green: 0.58, blue: 0.64)
    static let panel   = Color(red: 0.086, green: 0.102, blue: 0.129)
    static let edge    = Color(red: 0.15, green: 0.17, blue: 0.22)
    static let track   = Color(red: 0.15, green: 0.17, blue: 0.22)
    static let green   = Color(red: 0.25, green: 0.73, blue: 0.31)
    static let amber   = Color(red: 0.84, green: 0.64, blue: 0.20)
    static let gray    = Color(red: 0.43, green: 0.46, blue: 0.51)
    static let red     = Color(red: 0.97, green: 0.32, blue: 0.29)

    static func load(_ pct: Int) -> Color {
        pct >= 85 ? red : (pct >= 60 ? amber : green)
    }

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
