import Foundation

/// The outcome of sending a notification through WendyOS.
public struct WendyNotificationSendResponse: Sendable, Hashable {
  /// The canonical caller-generated Notification identifier accepted by Wendy.
  public let notificationID: UUID

  /// The unique recipients resolved by Wendy Cloud, capped at 10,000.
  public let recipientCount: Int

  public init(notificationID: UUID, recipientCount: Int) {
    self.notificationID = notificationID
    self.recipientCount = recipientCount
  }
}
