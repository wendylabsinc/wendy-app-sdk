/// The outcome of sending a notification through WendyOS.
public struct WendyNotificationSendResponse: Sendable, Hashable {
  public let isDuplicate: Bool

  /// The unique recipients resolved by Wendy Cloud, capped at 10,000.
  public let recipientCount: Int

  public init(isDuplicate: Bool, recipientCount: Int) {
    self.isDuplicate = isDuplicate
    self.recipientCount = recipientCount
  }
}
