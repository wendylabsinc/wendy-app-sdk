/// An available WiFi network from wendy-agent's ListWiFiNetworks RPC.
public struct WiFiNetwork: Equatable, Sendable, Identifiable {
    public var ssid: String
    public var signalStrength: Int?
    public var isKnown: Bool
    public var isConnected: Bool

    public var id: String { ssid }

    public init(ssid: String, signalStrength: Int?, isKnown: Bool, isConnected: Bool) {
        self.ssid = ssid
        self.signalStrength = signalStrength
        self.isKnown = isKnown
        self.isConnected = isConnected
    }
}

extension WiFiNetwork {
    init(_ n: Wendy_Agent_Services_V1_ListWiFiNetworksResponse.WiFiNetwork) {
        self.init(
            ssid: n.ssid,
            signalStrength: n.hasSignalStrength ? Int(n.signalStrength) : nil,
            isKnown: n.isKnown,
            isConnected: n.isConnected
        )
    }
}

/// Current WiFi connection state from wendy-agent's GetWiFiStatus RPC.
public struct WiFiStatus: Equatable, Sendable {
    public var connected: Bool
    public var ssid: String?

    public init(connected: Bool, ssid: String?) {
        self.connected = connected
        self.ssid = ssid
    }
}

extension WiFiStatus {
    init(_ r: Wendy_Agent_Services_V1_GetWiFiStatusResponse) {
        self.init(connected: r.connected, ssid: r.hasSsid ? r.ssid : nil)
    }
}
