/// The notification content and audience supplied by a Wendy app.
public struct WendyNotificationSendRequest: Equatable, Sendable {
  public var notification: WendyNotification

  public init(notification: WendyNotification) {
    self.notification = notification
  }

  public init(
    audience: WendyAudience,
    title: String,
    body: String,
    severity: WendyNotificationSeverity,
    deepLink: String,
    sourceID: String,
    metadata: [String: WendyJSONValue]? = nil
  ) {
    self.notification = WendyNotification(
      audience: audience,
      title: title,
      body: body,
      severity: severity,
      deepLink: deepLink,
      sourceID: sourceID,
      metadata: metadata
    )
  }
}
