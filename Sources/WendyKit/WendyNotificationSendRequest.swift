import Foundation

/// The notification content and audience supplied by a Wendy app.
public struct WendyNotificationSendRequest: Sendable, Hashable {
  /// The normalized user, team, and role selector union for this delivery.
  public var audience: WendyAudience
  public var title: String
  public var body: String
  public var severity: WendyNotificationSeverity
  public var deepLink: String

  /// The canonical caller-generated Notification identifier.
  ///
  /// The default is generated once when this request is initialized. Retain and
  /// resend the same request—or explicitly reuse this value—for retries.
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
  ) {
    self.audience = audience
    self.title = title
    self.body = body
    self.severity = severity
    self.deepLink = deepLink
    self.notificationID = notificationID
    self.metadata = metadata
  }
}
