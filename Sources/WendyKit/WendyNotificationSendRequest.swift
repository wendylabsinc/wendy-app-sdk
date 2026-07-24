/// The notification content and audience supplied by a Wendy app.
public struct WendyNotificationSendRequest: Sendable, Hashable {
  /// The normalized user, team, and role selector union for this delivery.
  public var audience: WendyAudience
  public var title: String
  public var body: String
  public var severity: WendyNotificationSeverity
  public var deepLink: String
  public var sourceID: String
  public var metadata: WendyNotificationMetadata?

  public init(
    audience: WendyAudience,
    title: String,
    body: String,
    severity: WendyNotificationSeverity,
    deepLink: String,
    sourceID: String,
    metadata: WendyNotificationMetadata? = nil
  ) {
    self.audience = audience
    self.title = title
    self.body = body
    self.severity = severity
    self.deepLink = deepLink
    self.sourceID = sourceID
    self.metadata = metadata
  }
}
