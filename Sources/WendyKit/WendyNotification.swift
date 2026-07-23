/// An operator-facing notification created by a Wendy app.
///
/// This value contains notification domain data only. It does not expose how
/// WendyOS sends the notification or how a client eventually receives it.
public struct WendyNotification: Equatable, Sendable {
  public let audience: WendyAudience
  public let title: String
  public let body: String
  public let severity: WendyNotificationSeverity
  public let deepLink: String
  public let sourceID: String
  public let metadata: [String: WendyJSONValue]?

  public init(
    audience: WendyAudience,
    title: String,
    body: String,
    severity: WendyNotificationSeverity,
    deepLink: String,
    sourceID: String,
    metadata: [String: WendyJSONValue]? = nil
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
