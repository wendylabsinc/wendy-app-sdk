import Foundation

/// The notification content and audience supplied by a Wendy app.
public struct WendyNotificationSendRequest: Sendable, Hashable {
  /// The normalized user, team, and role selector union for this delivery.
  public var audience: WendyAudience
  public var title: String
  public var body: String
  public var severity: WendyNotificationSeverity
  public var deepLink: String

  /// The caller-generated UUID v4 identifying the Notification resource.
  ///
  /// The default is generated once and retained by this request. Reusing the ID
  /// after a successful creation throws `WendyError.notificationAlreadyExists`;
  /// Wendy does not replay the original response. Retaining it is appropriate
  /// when an attempt was rejected locally or was known not to reach Wendy Cloud.
  /// After an ambiguous post-Cloud failure, a retry may report that the resource
  /// already exists.
  public let notificationID: UUID

  public var metadata: WendyNotificationMetadata?

  public init(
    audience: WendyAudience,
    title: String,
    body: String,
    severity: WendyNotificationSeverity,
    deepLink: String,
    notificationID: UUID = UUID(),
    metadata: WendyNotificationMetadata? = nil
  ) throws {
    guard isNotificationUUIDv4(notificationID) else {
      throw WendyError.invalidRequest("notification_id must be a UUID v4")
    }

    self.audience = audience
    self.title = title
    self.body = body
    self.severity = severity
    self.deepLink = deepLink
    self.notificationID = notificationID
    self.metadata = metadata
  }
}

func isNotificationUUIDv4(_ notificationID: UUID) -> Bool {
  let bytes = notificationID.uuid
  return bytes.6 & 0xf0 == 0x40 && bytes.8 & 0xc0 == 0x80
}
