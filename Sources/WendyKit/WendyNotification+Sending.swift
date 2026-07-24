import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import IkigaJSON
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
    self.init()
    self.audience = Wendy_System_V1_NotificationAudience(request.audience)
    self.title = request.title
    self.body = request.body
    self.severity = try Wendy_System_V1_NotificationSeverity(request.severity)
    self.deepLink = request.deepLink
    self.sourceID = request.sourceID
    if let metadata = request.metadata {
      self.metadata = try Google_Protobuf_Struct(metadata.jsonObject())
    }
  }
}

extension Wendy_System_V1_NotificationAudience {
  init(_ audience: WendyAudience) {
    self.init()
    switch audience {
    case .user(let id):
      self.userID = id
    case .organizationTeam(let id):
      self.orgTeamID = id
    case .organizationRole(let role):
      self.organizationRole = Wendy_System_V1_OrganizationRole(role)
    }
  }
}

extension Wendy_System_V1_NotificationSeverity {
  init(_ severity: WendyNotificationSeverity) throws {
    switch severity {
    case .unspecified:
      throw WendyError.invalidRequest("severity must be specified")
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
  init(_ role: WendyOrganizationRole) {
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
  init(_ object: JSONObject) throws {
    self.init()
    for key in object.keys {
      guard let value = object[key] else { continue }
      self.fields[key] = try Google_Protobuf_Value(value)
    }
  }
}

extension Google_Protobuf_Value {
  init(_ value: any JSONValue) throws {
    self.init()
    switch value {
    case let value as JSONObject:
      self.structValue = try Google_Protobuf_Struct(value)
    case let value as JSONArray:
      var list = Google_Protobuf_ListValue()
      list.values = try value.map(Google_Protobuf_Value.init)
      self.listValue = list
    case let value as Bool:
      self.boolValue = value
    case let value as String:
      self.stringValue = value
    case let value as Int:
      self.numberValue = Double(value)
    case let value as Double:
      guard value.isFinite else {
        throw WendyError.invalidRequest("metadata numbers must be finite")
      }
      self.numberValue = value
    case is NSNull:
      self.nullValue = .nullValue
    default:
      throw WendyError.invalidRequest("metadata contains an unsupported JSON value")
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
