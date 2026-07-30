import Foundation

/// An operator-facing notification stored by Wendy Cloud.
///
/// This value contains notification domain data only. It does not expose how
/// WendyOS sends the notification or how a client eventually receives it.
public struct WendyNotification: Identifiable, Sendable, Hashable {
  public let id: WendyNotificationID
  public let organizationID: WendyOrganizationID
  public let title: String?
  public let body: String
  public let severity: WendyNotificationSeverity
  public let deepLink: String?
  public let source: WendyNotificationSource?
  public let audience: WendyAudience?
  public let metadata: WendyNotificationMetadata?
  public let relatedEntities: WendyNotificationMetadata?
  public let createdAt: Date?

  public init(
    id: WendyNotificationID,
    organizationID: WendyOrganizationID,
    body: String,
    severity: WendyNotificationSeverity,
    createdAt: Date?,
    title: String? = nil,
    deepLink: String? = nil,
    source: WendyNotificationSource? = nil,
    audience: WendyAudience? = nil,
    metadata: WendyNotificationMetadata? = nil,
    relatedEntities: WendyNotificationMetadata? = nil
  ) {
    self.id = id
    self.organizationID = organizationID
    self.title = title
    self.body = body
    self.severity = severity
    self.deepLink = deepLink
    self.source = source
    self.audience = audience
    self.metadata = metadata
    self.relatedEntities = relatedEntities
    self.createdAt = createdAt
  }
}
