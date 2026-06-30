// Imports SwiftCrossUI (not Combine/Foundation) for ObservableObject/@Published:
// SwiftCrossUI v0.7.0 ships its own observation types, and its views only react to
// those — so a view-model the UI observes must use them. This couples the sample's
// model to the UI framework, which is acceptable for an app target (not a library).
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
