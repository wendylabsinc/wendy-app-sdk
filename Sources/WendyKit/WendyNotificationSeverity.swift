/// The urgency of a Wendy notification.
public enum WendyNotificationSeverity: Sendable, Hashable {
  /// The runtime did not provide a recognized severity.
  case unspecified
  case info
  case warning
  case error
  case critical
}
