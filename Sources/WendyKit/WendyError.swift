/// Errors WendyKit can diagnose while using a Wendy System API.
public enum WendyError: Error, Equatable, Sendable {
  /// The app is not running with a supported WendyOS System API runtime.
  /// This can also mean the app did not declare the capability's entitlement.
  case unavailable

  /// The app is missing the `notifications` entitlement.
  case notificationsEntitlementRequired

  /// The request cannot be represented by the Wendy Notifications API.
  case invalidRequest(String)

  /// WendyOS rejected or could not complete the operation.
  case operationFailed(String)
}

// MARK: - CustomStringConvertible

extension WendyError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .unavailable:
      return
        "The Wendy System API is unavailable. Run the app on a supported WendyOS version and declare the notifications entitlement."
    case .notificationsEntitlementRequired:
      return "Sending notifications requires the notifications entitlement in wendy.json."
    case .invalidRequest(let reason):
      return "The notification request is invalid: \(reason)"
    case .operationFailed(let reason):
      return "WendyOS could not send the notification: \(reason)"
    }
  }
}
