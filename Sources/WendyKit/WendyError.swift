import Foundation

/// Errors shared by Wendy APIs.
public enum WendyError: Error, Sendable, Equatable {
  /// The requested operation is not supported by the active Wendy connection.
  case notAvailableOnTransport

  /// WendyKit could not establish a connection.
  case connectionFailed(String)

  /// The connection ended while an operation was running.
  case disconnected

  /// Wendy returned an operation error.
  case deviceError(String)

  /// WendyKit received malformed or unexpected protocol data.
  case protocolError(String)

  /// The app is not running with a supported WendyOS System API runtime.
  /// This can also mean the app did not declare the capability's entitlement.
  case unavailable

  /// The app is missing the `notifications` entitlement.
  case notificationsEntitlementRequired

  /// The request cannot be represented by the Wendy API.
  case invalidRequest(String)

  /// WendyOS rejected or could not complete the operation.
  case operationFailed(String)
}

// MARK: - CustomStringConvertible

extension WendyError: CustomStringConvertible {
  public var description: String {
    self.errorDescription ?? "Wendy API error."
  }
}

// MARK: - LocalizedError

extension WendyError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .notAvailableOnTransport:
      return "The requested operation is not available over the current Wendy connection."
    case .connectionFailed(let reason):
      return "WendyKit could not establish a connection: \(reason)"
    case .disconnected:
      return "The Wendy connection ended before the operation completed."
    case .deviceError(let reason):
      return "Wendy could not complete the operation: \(reason)"
    case .protocolError(let reason):
      return "WendyKit received invalid protocol data: \(reason)"
    case .unavailable:
      return
        "The Wendy System API is unavailable. Run the app on a supported WendyOS version and declare the notifications entitlement."
    case .notificationsEntitlementRequired:
      return "Sending notifications requires the notifications entitlement in wendy.json."
    case .invalidRequest(let reason):
      return "The Wendy request is invalid: \(reason)"
    case .operationFailed(let reason):
      return "WendyOS could not complete the operation: \(reason)"
    }
  }
}
