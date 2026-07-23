import Foundation
import GRPCCore
import SwiftProtobuf
import Testing

@testable import WendyKit

@Test
func `send request stores the shared notification domain value`() {
  let notification = WendyNotification(
    audience: .organizationRole(.admin),
    title: "Fire detected",
    body: "Camera 2 detected smoke.",
    severity: .critical,
    deepLink: "wendy://devices/42/live?camera=2",
    sourceID: "fire-2026-07-23-001",
    metadata: ["confidence": .number(0.98)]
  )

  let request = WendyNotificationSendRequest(notification: notification)

  #expect(request.notification == notification)
}

@Test(
  arguments: [
    (WendyNotification.Audience.user(id: "user-1"), "user-1", Int32(0), nil),
    (WendyNotification.Audience.team(id: 42), "", Int32(42), nil),
    (
      WendyNotification.Audience.organizationRole(.billingManager),
      "",
      Int32(0),
      Wendy_System_V1_OrganizationRole.billingManager
    ),
  ]
)
func `audiences map to the local System API contract`(
  audience: WendyNotification.Audience,
  userID: String,
  teamID: Int32,
  role: Wendy_System_V1_OrganizationRole?
) throws {
  let proto = try Wendy_System_V1_NotificationAudience(audience)

  #expect(proto.userID == userID)
  #expect(proto.orgTeamID == teamID)
  if let role {
    #expect(proto.organizationRole == role)
  }
}

@Test
func `send request maps content and nested JSON metadata`() throws {
  let request = WendyNotificationSendRequest(
    audience: .user(id: "operator-1"),
    title: "Leak detected",
    body: "Pressure fell below the configured threshold.",
    severity: .warning,
    deepLink: "wendy://devices/7/live",
    sourceID: "leak-17",
    metadata: [
      "acknowledged": .bool(false),
      "reading": .number(12.5),
      "labels": .array([.string("water"), .null]),
      "sensor": .object(["id": .string("pressure-4")]),
    ]
  )

  let proto = try Wendy_System_V1_SendRequest(request)

  #expect(proto.audience.userID == "operator-1")
  #expect(proto.title == "Leak detected")
  #expect(proto.body == "Pressure fell below the configured threshold.")
  #expect(proto.severity == .warning)
  #expect(proto.deepLink == "wendy://devices/7/live")
  #expect(proto.sourceID == "leak-17")
  #expect(proto.hasMetadata)
  #expect(proto.metadata.fields["acknowledged"]?.boolValue == false)
  #expect(proto.metadata.fields["reading"]?.numberValue == 12.5)
  #expect(proto.metadata.fields["labels"]?.listValue.values.count == 2)
  #expect(proto.metadata.fields["sensor"]?.structValue.fields["id"]?.stringValue == "pressure-4")
}

@Test
func `absent metadata remains absent in the wire request`() throws {
  let request = WendyNotificationSendRequest(
    audience: .team(id: 3),
    title: "Inspection due",
    body: "Inspect line 2.",
    severity: .info,
    deepLink: "wendy://devices/8",
    sourceID: "inspection-3"
  )

  #expect(try !Wendy_System_V1_SendRequest(request).hasMetadata)
}

@Test
func `non-finite metadata numbers are rejected before transport`() {
  let request = WendyNotificationSendRequest(
    audience: .user(id: "user-1"),
    title: "Invalid reading",
    body: "The sensor returned an invalid reading.",
    severity: .error,
    deepLink: "wendy://devices/9",
    sourceID: "invalid-reading",
    metadata: ["reading": .number(.infinity)]
  )

  #expect(throws: WendyError.invalidRequest("metadata numbers must be finite")) {
    _ = try Wendy_System_V1_SendRequest(request)
  }
}

@Test
func `team IDs outside the wire range are rejected`() {
  #expect(throws: WendyError.invalidRequest("team ID is outside the supported range")) {
    _ = try Wendy_System_V1_NotificationAudience(.team(id: Int.max))
  }
}

@Test
func `send response exposes only delivery outcome`() {
  var proto = Wendy_System_V1_SendResponse()
  proto.duplicate = true
  proto.recipientCount = 12

  let response = WendyNotificationSendResponse(proto)

  #expect(response.isDuplicate)
  #expect(response.recipientCount == 12)
}

@Test(
  arguments: [
    (RPCError.Code.permissionDenied, WendyError.notificationsEntitlementRequired),
    (RPCError.Code.unimplemented, WendyError.unavailable),
    (
      RPCError.Code.invalidArgument,
      WendyError.invalidRequest("title is required")
    ),
  ]
)
func `transport failures map to domain errors`(
  code: RPCError.Code,
  expected: WendyError
) {
  #expect(WendyError(RPCError(code: code, message: "title is required")) == expected)
}

@Test
func `static send delegates without exposing a service API`() async throws {
  let expected = WendyNotificationSendResponse(isDuplicate: false, recipientCount: 2)
  let sender = StubNotificationSender(response: expected)
  let request = WendyNotificationSendRequest(
    audience: .organizationRole(.owner),
    title: "Device offline",
    body: "The device stopped reporting.",
    severity: .critical,
    deepLink: "wendy://devices/10",
    sourceID: "offline-10"
  )

  let response = try await WendyNotification.send(request, using: sender)

  #expect(response == expected)
}

@Suite(.serialized)
struct WendySystemEnvironmentTests {
  @Test
  func `static send clearly reports a missing System API runtime`() async {
    let oldValue = ProcessInfo.processInfo.environment[
      WendySystemNotificationTransport.environmentVariable]
    unsetenv(WendySystemNotificationTransport.environmentVariable)
    defer {
      if let oldValue {
        setenv(WendySystemNotificationTransport.environmentVariable, oldValue, 1)
      }
    }

    let request = WendyNotificationSendRequest(
      audience: .user(id: "user-1"),
      title: "Test",
      body: "Test",
      severity: .info,
      deepLink: "wendy://test",
      sourceID: "test"
    )

    await #expect(throws: WendyError.unavailable) {
      _ = try await WendyNotification.send(request)
    }
  }

  @Test
  func `System API transport discovers the app-private runtime path`() {
    let oldValue = ProcessInfo.processInfo.environment[
      WendySystemNotificationTransport.environmentVariable]
    setenv(WendySystemNotificationTransport.environmentVariable, "/run/wendy/system/system.sock", 1)
    defer {
      if let oldValue {
        setenv(WendySystemNotificationTransport.environmentVariable, oldValue, 1)
      } else {
        unsetenv(WendySystemNotificationTransport.environmentVariable)
      }
    }

    #expect(
      WendySystemNotificationTransport.fromEnvironment()?.socketPath
        == "/run/wendy/system/system.sock")
  }
}

private struct StubNotificationSender: WendyNotificationSending {
  let response: WendyNotificationSendResponse

  func send(_ request: WendyNotificationSendRequest) async throws -> WendyNotificationSendResponse {
    response
  }
}
