import SwiftCrossUI
import WendyKit

/// What the sample's UI needs from a data source. WendyAgent conforms; tests
/// inject a fake. Keeping the abstraction in the app (not WendyKit) keeps the
/// SDK surface to the concrete WendyAgent while leaving the app unit-testable.
public protocol DeviceStatusProviding: Sendable {
    func deviceVersion() async throws -> DeviceVersion
    func apps() async throws -> [AppSummary]
}

extension WendyAgent: DeviceStatusProviding {}

/// Loads device status + apps for display. Demonstrates the recommended pattern:
/// WendyKit throws; the *app* decides the fallback (here, an "unavailable" line).
@MainActor
final class DeviceStatusModel: ObservableObject {
    @Published var line: String = "loading…"
    @Published var apps: [AppSummary] = []

    private let provider: DeviceStatusProviding

    init(provider: DeviceStatusProviding) {
        self.provider = provider
    }

    func load() async {
        do {
            let v = try await provider.deviceVersion()
            line = "\(v.os) \(v.osVersion ?? "?") · agent \(v.agentVersion)"
        } catch {
            line = "device status unavailable"
        }
        do {
            apps = try await provider.apps()
        } catch {
            apps = []
        }
    }
}
