/// A legacy per-recipient projection identifier used by the Companion read model.
///
/// This is not the canonical app-originated Notification resource identity. New
/// sends use the UUID v4 in `WendyNotificationSendRequest.notificationID`; the
/// legacy integer remains until the read model migrates to canonical UUID APIs.
public struct WendyNotificationID: RawRepresentable, Sendable, Hashable {
  public let rawValue: Int32

  public init(rawValue: Int32) {
    self.rawValue = rawValue
  }
}
