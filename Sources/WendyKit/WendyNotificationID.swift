/// The Cloud-assigned identifier of a Wendy notification.
public struct WendyNotificationID: RawRepresentable, Sendable, Hashable {
  public let rawValue: Int32

  public init(rawValue: Int32) {
    self.rawValue = rawValue
  }
}
