/// The urgency of a Wendy notification.
public enum WendyNotificationSeverity: String, CaseIterable, Equatable, Sendable {
  case info
  case warning
  case error
  case critical
}
