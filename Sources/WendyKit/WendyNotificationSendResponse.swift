/// The outcome of sending a notification through WendyOS.
public struct WendyNotificationSendResponse: Sendable, Hashable {
  public let isDuplicate: Bool
  public let recipientCount: Int

  public init(isDuplicate: Bool, recipientCount: Int) {
    self.isDuplicate = isDuplicate
    self.recipientCount = recipientCount
  }
}
