/// The authenticated source that created a Wendy notification.
public struct WendyNotificationSource: Sendable, Hashable {
  public let id: String?
  public let userID: String?
  public let assetID: Int32?
  public let appID: String?

  public init(
    id: String? = nil,
    userID: String? = nil,
    assetID: Int32? = nil,
    appID: String? = nil
  ) {
    self.id = id
    self.userID = userID
    self.assetID = assetID
    self.appID = appID
  }
}
