import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2

/// Typed async client for wendy-agent over its local unix socket. The `admin`
/// entitlement bind-mounts the socket at `WENDY_AGENT_SOCKET` (no mTLS). Calls
/// throw on transport/RPC failure — the SDK does not substitute placeholder data.
public struct WendyAgent: Sendable {
    public let socketPath: String

    public init(socketPath: String) {
        self.socketPath = socketPath
    }

    /// Builds an agent from `WENDY_AGENT_SOCKET`. Returns nil when the variable is
    /// unset or empty (e.g. running off-device, or without the `admin`
    /// entitlement) — a distinct, non-throwing signal so callers can branch.
    public static func fromEnvironment() -> WendyAgent? {
        guard let sock = ProcessInfo.processInfo.environment["WENDY_AGENT_SOCKET"],
              !sock.isEmpty
        else { return nil }
        return WendyAgent(socketPath: sock)
    }

    private func withClient<R: Sendable>(
        _ body: @Sendable @escaping (GRPCClient<HTTP2ClientTransport.Posix>) async throws -> R
    ) async throws -> R {
        let transport = try HTTP2ClientTransport.Posix(
            target: .unixDomainSocket(path: socketPath),
            transportSecurity: .plaintext
        )
        return try await withGRPCClient(transport: transport) { client in
            try await body(client)
        }
    }

    /// Device identity/version (GetAgentVersion RPC).
    public func deviceVersion() async throws -> DeviceVersion {
        try await withClient { client in
            let agent = Wendy_Agent_Services_V1_WendyAgentService.Client(wrapping: client)
            return try await agent.getAgentVersion(.init()) { response in
                DeviceVersion(try response.message)
            }
        }
    }

    /// Deployed apps and their state (ListContainers server-streaming RPC).
    public func apps() async throws -> [AppSummary] {
        try await withClient { client in
            let containers = Wendy_Agent_Services_V1_WendyContainerService.Client(wrapping: client)
            return try await containers.listContainers(.init()) { response in
                var apps: [AppSummary] = []
                for try await msg in response.messages {
                    apps.append(AppSummary(msg.container))
                }
                return apps
            }
        }
    }
}
