import Testing
import SwiftProtobuf
@testable import WendyKit

@Test func deviceVersionMapsPresentAndAbsentOptionals() {
    var msg = Wendy_Agent_Services_V1_GetAgentVersionResponse()
    msg.version = "1.2.3"
    msg.os = "wendyos"
    msg.osVersion = "0.16.0"
    msg.cpuArchitecture = "arm64"
    msg.deviceType = "jetson-orin-nano"
    msg.hasGpu_p = true

    let dv = DeviceVersion(msg)
    #expect(dv.agentVersion == "1.2.3")
    #expect(dv.os == "wendyos")
    #expect(dv.osVersion == "0.16.0")
    #expect(dv.cpuArchitecture == "arm64")
    #expect(dv.deviceType == "jetson-orin-nano")
    #expect(dv.hasGPU == true)
}

@Test func deviceVersionAbsentOptionalsBecomeNil() {
    var msg = Wendy_Agent_Services_V1_GetAgentVersionResponse()
    msg.version = "9.9.9"
    msg.os = "linux"
    // os_version, device_type left unset; has_gpu unset → false
    let dv = DeviceVersion(msg)
    #expect(dv.osVersion == nil)
    #expect(dv.deviceType == nil)
    #expect(dv.hasGPU == false)
}

@Test func deviceVersionPresentGpuFalse() {
    var msg = Wendy_Agent_Services_V1_GetAgentVersionResponse()
    msg.version = "2.0.0"
    msg.os = "wendyos"
    // Explicitly set the presence bit but leave the value false
    msg.hasGpu_p = false
    let dv = DeviceVersion(msg)
    #expect(dv.hasGPU == false)
}

@Test func appSummaryRunning() {
    var c = AppContainer()
    c.appName = "sh.wendy.shell"
    c.appVersion = "0.1.0"
    c.runningState = .running
    let app = AppSummary(c)
    #expect(app.id == "sh.wendy.shell")
    #expect(app.appVersion == "0.1.0")
    #expect(app.state == .running)
}

@Test func appSummaryFailedTakesPrecedenceOverStopped() {
    var c = AppContainer()
    c.appName = "com.example.broken"
    c.runningState = .stopped
    c.failureCount = 3
    #expect(AppSummary(c).state == .failed(count: 3))
}

@Test func appSummaryStopped() {
    var c = AppContainer()
    c.appName = "com.example.idle"
    c.runningState = .stopped
    c.failureCount = 0
    #expect(AppSummary(c).state == .stopped)
}

@Test func wifiNetworkMapsFields() {
    var n = Wendy_Agent_Services_V1_ListWiFiNetworksResponse.WiFiNetwork()
    n.ssid = "Wendy-Lab"
    n.signalStrength = 72
    n.isKnown = true
    n.isConnected = true
    let w = WiFiNetwork(n)
    #expect(w.id == "Wendy-Lab")
    #expect(w.signalStrength == 72)
    #expect(w.isKnown)
    #expect(w.isConnected)
}

@Test func wifiNetworkAbsentSignalIsNil() {
    var n = Wendy_Agent_Services_V1_ListWiFiNetworksResponse.WiFiNetwork()
    n.ssid = "Hidden"
    // signal_strength unset
    #expect(WiFiNetwork(n).signalStrength == nil)
}

@Test func wifiStatusConnected() {
    var r = Wendy_Agent_Services_V1_GetWiFiStatusResponse()
    r.connected = true
    r.ssid = "Wendy-Lab"
    let s = WiFiStatus(r)
    #expect(s.connected)
    #expect(s.ssid == "Wendy-Lab")
}

@Test func wifiStatusDisconnectedHasNoSSID() {
    var r = Wendy_Agent_Services_V1_GetWiFiStatusResponse()
    r.connected = false
    #expect(WiFiStatus(r).ssid == nil)
}
