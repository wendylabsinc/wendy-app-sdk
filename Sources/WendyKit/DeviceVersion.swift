/// Device identity/version reported by wendy-agent's GetAgentVersion RPC.
public struct DeviceVersion: Equatable, Sendable {
    public var agentVersion: String
    public var os: String
    public var osVersion: String?
    public var cpuArchitecture: String
    public var deviceType: String?
    public var hasGPU: Bool

    public init(
        agentVersion: String, os: String, osVersion: String?,
        cpuArchitecture: String, deviceType: String?, hasGPU: Bool
    ) {
        self.agentVersion = agentVersion
        self.os = os
        self.osVersion = osVersion
        self.cpuArchitecture = cpuArchitecture
        self.deviceType = deviceType
        self.hasGPU = hasGPU
    }
}

extension DeviceVersion {
    /// Maps the agent's GetAgentVersion response into the SDK value type.
    /// Proto3 `optional` string fields use presence (`has*`) so unset → nil.
    /// Note: the proto field `has_gpu` generates as `hasGpu_p` (Swift appends
    /// `_p` to avoid clashing with the SwiftProtobuf presence accessor prefix),
    /// and its presence accessor is `hasHasGpu_p`.
    init(_ r: Wendy_Agent_Services_V1_GetAgentVersionResponse) {
        self.init(
            agentVersion: r.version,
            os: r.os,
            osVersion: r.hasOsVersion ? r.osVersion : nil,
            cpuArchitecture: r.cpuArchitecture,
            deviceType: r.hasDeviceType ? r.deviceType : nil,
            hasGPU: r.hasHasGpu_p ? r.hasGpu_p : false // proto3 optional bool: absence means false, not "GPU unknown"
        )
    }
}
