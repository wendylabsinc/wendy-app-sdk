import Testing
import Foundation
@testable import WendyKit

@Test func fromEnvironmentNilWhenUnset() {
    setenv("WENDY_AGENT_SOCKET", "", 1)
    #expect(WendyAgent.fromEnvironment() == nil)
    unsetenv("WENDY_AGENT_SOCKET")
    #expect(WendyAgent.fromEnvironment() == nil)
}

@Test func fromEnvironmentReadsSocketPath() {
    setenv("WENDY_AGENT_SOCKET", "/run/wendy/agent.sock", 1)
    let agent = WendyAgent.fromEnvironment()
    #expect(agent?.socketPath == "/run/wendy/agent.sock")
    unsetenv("WENDY_AGENT_SOCKET")
}

@Test func deviceVersionThrowsAgainstDeadSocket() async {
    let agent = WendyAgent(socketPath: "/tmp/wendy-app-sdk-nonexistent.sock")
    await #expect(throws: (any Error).self) {
        _ = try await agent.deviceVersion()
    }
}
