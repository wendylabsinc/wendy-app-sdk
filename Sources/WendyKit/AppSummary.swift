/// A deployed app as wendy-agent's ListContainers RPC reports it.
public struct AppSummary: Equatable, Sendable, Identifiable {
    public enum State: Equatable, Sendable {
        case running
        case stopped
        case failed(count: Int)
    }

    public var appName: String
    public var appVersion: String
    public var state: State

    public var id: String { appName }

    public init(appName: String, appVersion: String, state: State) {
        self.appName = appName
        self.appVersion = appVersion
        self.state = state
    }
}

extension AppSummary {
    /// Maps a shared AppContainer proto message into the SDK value type.
    /// Note: AppContainer is not prefixed with Wendy_Agent_Services_V1_ in the
    /// generated stubs (it lives in shared.proto without a package-level Swift prefix).
    init(_ c: AppContainer) {
        let state: State
        if c.runningState == .running {
            state = .running
        } else if c.failureCount > 0 {
            state = .failed(count: Int(c.failureCount))
        } else {
            state = .stopped
        }
        self.init(appName: c.appName, appVersion: c.appVersion, state: state)
    }
}
