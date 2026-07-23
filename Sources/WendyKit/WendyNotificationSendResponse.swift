/// The outcome of sending a notification through WendyOS.
public struct WendyNotificationSendResponse: Equatable, Sendable {
  public let isDuplicate: Bool
  public let recipientCount: Int

  public init(isDuplicate: Bool, recipientCount: Int) {
    self.isDuplicate = isDuplicate
    self.recipientCount = recipientCount
  }
}
