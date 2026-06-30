import Foundation

/// Live CPU / memory / GPU utilisation read straight from the device. WendyKit
/// doesn't expose host telemetry, and this app runs *on* the device, so we read
/// the kernel interfaces directly. Linux-only; the macOS branch returns nil so
/// the dev build still compiles and the UI shows placeholders.
struct ResourceSample: Sendable {
    var cpuPercent: Int?
    var cpuDetail: String
    var memPercent: Int?
    var memDetail: String
    var gpuPercent: Int?
    var gpuDetail: String
}

/// Reads utilisation. CPU is a rate, so it needs two samples — hold one instance
/// and call `read()` on each refresh; the first call returns nil CPU.
final class SystemMetrics {
    private var prevCPU: (idle: Double, total: Double)?

    func read() -> ResourceSample {
        #if os(Linux)
        let mem = readMem()
        return ResourceSample(
            cpuPercent: readCPU(),
            cpuDetail: "\(coreCount) cores",
            memPercent: mem?.percent,
            memDetail: mem?.detail ?? "—",
            gpuPercent: readGPU(),
            gpuDetail: gpuName
        )
        #else
        // Dev placeholder (no /proc on macOS).
        return ResourceSample(
            cpuPercent: nil, cpuDetail: "\(coreCount) cores",
            memPercent: nil, memDetail: "—",
            gpuPercent: nil, gpuDetail: "—"
        )
        #endif
    }

    private var coreCount: Int { ProcessInfo.processInfo.activeProcessorCount }

    #if os(Linux)
    /// /proc/stat aggregate line → busy fraction since the previous read.
    private func readCPU() -> Int? {
        guard let stat = try? String(contentsOfFile: "/proc/stat", encoding: .utf8),
              let line = stat.split(separator: "\n").first(where: { $0.hasPrefix("cpu ") })
        else { return nil }
        let f = line.split(separator: " ").dropFirst().compactMap { Double($0) }
        guard f.count >= 4 else { return nil }
        let idle = f[3] + (f.count > 4 ? f[4] : 0)        // idle + iowait
        let total = f.reduce(0, +)
        defer { prevCPU = (idle, total) }
        guard let p = prevCPU else { return nil }          // need a delta
        let dTotal = total - p.total, dIdle = idle - p.idle
        guard dTotal > 0 else { return nil }
        return clampPercent((1 - dIdle / dTotal) * 100)
    }

    private func readMem() -> (percent: Int, detail: String)? {
        guard let mi = try? String(contentsOfFile: "/proc/meminfo", encoding: .utf8) else { return nil }
        var vals: [String: Double] = [:]
        for line in mi.split(separator: "\n") {
            let parts = line.split(separator: ":")
            guard parts.count == 2 else { continue }
            vals[String(parts[0])] = Double(parts[1].split(separator: " ").first ?? "")  // kB
        }
        guard let total = vals["MemTotal"], total > 0 else { return nil }
        let avail = vals["MemAvailable"] ?? 0
        let used = total - avail
        let pct = clampPercent(used / total * 100)
        func gb(_ kb: Double) -> String { String(format: "%.1f", kb / 1_048_576) }
        return (pct, "\(gb(used)) / \(gb(total)) GB")
    }

    /// Jetson exposes GPU load (per-mille) in sysfs; the node path varies by SoC.
    private func readGPU() -> Int? {
        let candidates = [
            "/sys/devices/gpu.0/load",
            "/sys/devices/platform/gpu.0/load",
            "/sys/devices/platform/17000000.ga10b/load",   // Orin
            "/sys/devices/platform/17000000.gpu/load",
        ]
        for path in candidates {
            guard let raw = try? String(contentsOfFile: path, encoding: .utf8),
                  let perMille = Double(raw.trimmingCharacters(in: .whitespacesAndNewlines))
            else { continue }
            return clampPercent(perMille / 10)
        }
        return nil
    }

    private var gpuName: String { "GPU" }

    private func clampPercent(_ v: Double) -> Int { max(0, min(100, Int(v.rounded()))) }
    #endif
}
