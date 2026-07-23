/// An operator-facing notification created by a Wendy app.
///
/// This value contains notification domain data only. It does not expose how
/// WendyOS sends the notification or how a client eventually receives it.
public struct WendyNotification: Equatable, Sendable {
  /// The users who should receive a notification.
  public enum Audience: Equatable, Sendable {
    /// One Wendy user.
    case user(id: String)

    /// Every member of an organization team.
    case team(id: Int)

    /// Every organization member with a specific role.
    case organizationRole(OrganizationRole)
  }

  /// A role in a Wendy organization.
  public enum OrganizationRole: String, CaseIterable, Equatable, Sendable {
    case owner
    case admin
    case billingManager = "billing_manager"
    case member
    case viewer
  }

  /// The urgency presented to recipients.
  public enum Severity: String, CaseIterable, Equatable, Sendable {
    case info
    case warning
    case error
    case critical
  }

  public let audience: Audience
  public let title: String
  public let body: String
  public let severity: Severity
  public let deepLink: String
  public let sourceID: String
  public let metadata: [String: WendyNotificationMetadataValue]?

  public init(
    audience: Audience,
    title: String,
    body: String,
    severity: Severity,
    deepLink: String,
    sourceID: String,
    metadata: [String: WendyNotificationMetadataValue]? = nil
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

/// A JSON-compatible metadata value attached to a notification.
///
/// Numbers must be finite. WendyKit rejects non-finite values before sending
/// the request.
public indirect enum WendyNotificationMetadataValue: Equatable, Sendable {
  case null
  case bool(Bool)
  case number(Double)
  case string(String)
  case array([WendyNotificationMetadataValue])
  case object([String: WendyNotificationMetadataValue])
}

/// The notification content and audience supplied by a Wendy app.
public struct WendyNotificationSendRequest: Equatable, Sendable {
  public var notification: WendyNotification

  public init(notification: WendyNotification) {
    self.notification = notification
  }

  public init(
    audience: WendyNotification.Audience,
    title: String,
    body: String,
    severity: WendyNotification.Severity,
    deepLink: String,
    sourceID: String,
    metadata: [String: WendyNotificationMetadataValue]? = nil
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

/// The outcome of sending a notification through WendyOS.
public struct WendyNotificationSendResponse: Equatable, Sendable {
  public let isDuplicate: Bool
  public let recipientCount: Int

  public init(isDuplicate: Bool, recipientCount: Int) {
    self.isDuplicate = isDuplicate
    self.recipientCount = recipientCount
  }
}
