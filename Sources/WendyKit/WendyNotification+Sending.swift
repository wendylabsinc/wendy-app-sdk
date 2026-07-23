import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import SwiftProtobuf

extension WendyNotification {
  /// Sends an operator-facing notification through WendyOS.
  ///
  /// The app must declare the `notifications` entitlement in `wendy.json` and
  /// run on a WendyOS version that provides the System API.
  public static func send(
    _ request: WendyNotificationSendRequest
  ) async throws -> WendyNotificationSendResponse {
    guard let transport = WendySystemNotificationTransport.fromEnvironment() else {
      throw WendyError.unavailable
    }

    return try await send(request, using: transport)
  }

  static func send(
    _ request: WendyNotificationSendRequest,
    using sender: some WendyNotificationSending
  ) async throws -> WendyNotificationSendResponse {
    try await sender.send(request)
  }
}

protocol WendyNotificationSending: Sendable {
  func send(_ request: WendyNotificationSendRequest) async throws -> WendyNotificationSendResponse
}

struct WendySystemNotificationTransport: WendyNotificationSending {
  static let environmentVariable = "WENDY_SYSTEM_SOCKET"

  let socketPath: String

  static func fromEnvironment() -> WendySystemNotificationTransport? {
    guard let socketPath = ProcessInfo.processInfo.environment[environmentVariable],
      !socketPath.isEmpty
    else {
      return nil
    }

    return WendySystemNotificationTransport(socketPath: socketPath)
  }

  func send(_ request: WendyNotificationSendRequest) async throws -> WendyNotificationSendResponse {
    let message = try Wendy_System_V1_SendRequest(request)

    do {
      let transport = try HTTP2ClientTransport.Posix(
        target: .unixDomainSocket(path: socketPath),
        transportSecurity: .plaintext
      )
      return try await withGRPCClient(transport: transport) { client in
        let notifications = Wendy_System_V1_NotificationService.Client(wrapping: client)
        return try await notifications.send(message) { response in
          WendyNotificationSendResponse(try response.message)
        }
      }
    } catch let error as RPCError {
      throw WendyError(error)
    } catch {
      throw WendyError.unavailable
    }
  }
}

extension Wendy_System_V1_SendRequest {
  init(_ request: WendyNotificationSendRequest) throws {
    let notification = request.notification
    self.init()
    self.audience = try Wendy_System_V1_NotificationAudience(notification.audience)
    self.title = notification.title
    self.body = notification.body
    self.severity = Wendy_System_V1_NotificationSeverity(notification.severity)
    self.deepLink = notification.deepLink
    self.sourceID = notification.sourceID
    if let metadata = notification.metadata {
      self.metadata = try Google_Protobuf_Struct(metadata)
    }
  }
}

extension Wendy_System_V1_NotificationAudience {
  init(_ audience: WendyNotification.Audience) throws {
    self.init()
    switch audience {
    case .user(let id):
      self.userID = id
    case .team(let id):
      guard let id = Int32(exactly: id) else {
        throw WendyError.invalidRequest("team ID is outside the supported range")
      }
      self.orgTeamID = id
    case .organizationRole(let role):
      self.organizationRole = Wendy_System_V1_OrganizationRole(role)
    }
  }
}

extension Wendy_System_V1_NotificationSeverity {
  init(_ severity: WendyNotification.Severity) {
    switch severity {
    case .info:
      self = .info
    case .warning:
      self = .warning
    case .error:
      self = .error
    case .critical:
      self = .critical
    }
  }
}

extension Wendy_System_V1_OrganizationRole {
  init(_ role: WendyNotification.OrganizationRole) {
    switch role {
    case .owner:
      self = .owner
    case .admin:
      self = .admin
    case .billingManager:
      self = .billingManager
    case .member:
      self = .member
    case .viewer:
      self = .viewer
    }
  }
}

extension Google_Protobuf_Struct {
  init(_ values: [String: WendyNotificationMetadataValue]) throws {
    self.init()
    self.fields = try values.mapValues(Google_Protobuf_Value.init)
  }
}

extension Google_Protobuf_Value {
  init(_ value: WendyNotificationMetadataValue) throws {
    self.init()
    switch value {
    case .null:
      self.nullValue = .nullValue
    case .bool(let value):
      self.boolValue = value
    case .number(let value):
      guard value.isFinite else {
        throw WendyError.invalidRequest("metadata numbers must be finite")
      }
      self.numberValue = value
    case .string(let value):
      self.stringValue = value
    case .array(let values):
      var list = Google_Protobuf_ListValue()
      list.values = try values.map(Google_Protobuf_Value.init)
      self.listValue = list
    case .object(let values):
      self.structValue = try Google_Protobuf_Struct(values)
    }
  }
}

extension WendyNotificationSendResponse {
  init(_ response: Wendy_System_V1_SendResponse) {
    self.init(
      isDuplicate: response.duplicate,
      recipientCount: Int(response.recipientCount)
    )
  }
}

extension WendyError {
  init(_ error: RPCError) {
    switch error.code {
    case .permissionDenied, .unauthenticated:
      self = .notificationsEntitlementRequired
    case .invalidArgument:
      self = .invalidRequest(error.message)
    case .unimplemented, .unavailable:
      self = .unavailable
    default:
      self = .operationFailed(error.message)
    }
  }
}
