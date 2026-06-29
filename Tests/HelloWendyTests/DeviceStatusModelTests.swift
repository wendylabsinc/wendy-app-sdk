import Testing
@testable import HelloWendy
import WendyKit

struct FakeProvider: DeviceStatusProviding {
    var version: DeviceVersion
    var appList: [AppSummary]
    var fail = false
    func deviceVersion() async throws -> DeviceVersion {
        if fail { throw FakeError.boom }
        return version
    }
    func apps() async throws -> [AppSummary] {
        if fail { throw FakeError.boom }
        return appList
    }
    enum FakeError: Error { case boom }
}

@MainActor
@Test func loadPopulatesLineAndApps() async {
    let provider = FakeProvider(
        version: DeviceVersion(agentVersion: "1.0.0", os: "wendyos", osVersion: "0.16.0",
                               cpuArchitecture: "arm64", deviceType: "jetson", hasGPU: true),
        appList: [AppSummary(appName: "sh.wendy.shell", appVersion: "0.1.0", state: .running)]
    )
    let model = DeviceStatusModel(provider: provider)
    await model.load()
    #expect(model.line.contains("wendyos"))
    #expect(model.line.contains("0.16.0"))
    #expect(model.apps.count == 1)
    #expect(model.apps.first?.state == .running)
}

@MainActor
@Test func loadDegradesToErrorLineOnFailure() async {
    let provider = FakeProvider(
        version: DeviceVersion(agentVersion: "", os: "", osVersion: nil,
                               cpuArchitecture: "", deviceType: nil, hasGPU: false),
        appList: [], fail: true)
    let model = DeviceStatusModel(provider: provider)
    await model.load()
    #expect(model.line.contains("unavailable"))
    #expect(model.apps.isEmpty)
}
