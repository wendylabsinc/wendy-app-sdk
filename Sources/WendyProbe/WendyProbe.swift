import Foundation
import WendyKit

// Headless on-device probe for the wendy-app-sdk. Runs as a `wendy run`
// container with the `admin` entitlement, connects to the live wendy-agent over
// WENDY_AGENT_SOCKET, and prints real device status / apps / wifi to stdout
// (which `wendy run` streams as console output). Exercises the whole WendyKit
// surface end-to-end against a real agent — the SDK's on-device smoke test.
@main
struct WendyProbe {
    static func main() async {
        print("=== wendy-app-sdk probe ===")

        guard let agent = WendyAgent.fromEnvironment() else {
            // Distinct, non-throwing signal: no socket means no `admin`
            // entitlement (or running off-device). Fail loudly so the test is
            // unambiguous rather than silently reporting nothing.
            print("WENDY_AGENT_SOCKET is not set.")
            print("Declare the `admin` entitlement in wendy.json and run on a WendyOS device.")
            exit(1)
        }
        print("agent socket: \(agent.socketPath)")

        await probe("device version") {
            let v = try await agent.deviceVersion()
            print("  os:    \(v.os) \(v.osVersion ?? "(version unknown)")")
            print("  agent: \(v.agentVersion)")
            print("  arch:  \(v.cpuArchitecture)")
            print("  type:  \(v.deviceType ?? "-")")
            print("  gpu:   \(v.hasGPU ? "yes" : "no")")
        }

        await probe("apps") {
            let apps = try await agent.apps()
            print("  \(apps.count) app(s):")
            for app in apps {
                print("  - \(app.appName) \(app.appVersion) [\(label(app.state))]")
            }
        }

        await probe("wifi status") {
            let status = try await agent.wifiStatus()
            if status.connected {
                print("  connected to \(status.ssid ?? "(unknown SSID)")")
            } else {
                print("  not connected")
            }
        }

        await probe("wifi networks") {
            let networks = try await agent.wifiNetworks()
            print("  \(networks.count) network(s):")
            for n in networks.prefix(15) {
                let signal = n.signalStrength.map { "\($0)%" } ?? "?"
                let flags = [n.isConnected ? "connected" : nil, n.isKnown ? "known" : nil]
                    .compactMap { $0 }.joined(separator: ", ")
                let suffix = flags.isEmpty ? "" : "  (\(flags))"
                print("  - \(n.ssid)  \(signal)\(suffix)")
            }
        }

        print("=== probe complete ===")
    }

    /// Runs one labelled WendyKit call, printing a header and turning a thrown
    /// error into a visible line rather than aborting the whole probe — so one
    /// failing RPC does not hide the others.
    private static func probe(_ name: String, _ body: sending () async throws -> Void) async {
        print("\n[\(name)]")
        do {
            try await body()
        } catch {
            print("  failed: \(error)")
        }
    }

    private static func label(_ state: AppSummary.State) -> String {
        switch state {
        case .running: return "running"
        case .stopped: return "stopped"
        case .failed(let count): return "failed (\(count))"
        }
    }
}
