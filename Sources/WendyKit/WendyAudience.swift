/// The users who should receive a Wendy notification.
///
/// The selector groups use set-union semantics: a user matching any user ID,
/// team ID, or role is included, and a recipient matching multiple selectors is
/// notified only once. Inputs are normalized, deduplicated, and sorted so equal
/// selector sets produce equal values regardless of input order.
///
/// An audience accepts at most `maximumSelectorCount` selectors after
/// deduplication. Wendy Cloud remains authoritative and separately caps the
/// resolved recipient union at 10,000 users.
public struct WendyAudience: Sendable, Hashable {
  /// The maximum number of unique selectors accepted by one audience.
  public static let maximumSelectorCount = 100

  /// The maximum encoded length of one user ID.
  public static let maximumUserIDByteCount = 128

  /// Explicit user IDs included in the audience.
  public let userIDs: [String]

  /// Legacy Cloud v1 numeric team IDs whose members are included in the audience.
  public let teamIDs: [Int32]

  /// Cloud v2 team UUIDs whose members are included in the audience.
  public let teamUUIDs: [String]

  /// Organization roles whose members are included in the audience.
  public let roles: [WendyOrganizationRole]

  /// Creates an audience from one or more user, team, or role selectors.
  ///
  /// Leading and trailing whitespace is removed from user IDs. All selector
  /// groups are deduplicated and sorted. The initializer rejects user IDs that
  /// are not 1...128 safe ASCII bytes, nonpositive legacy team IDs,
  /// noncanonical team UUIDs, mixed legacy and UUID team selectors, empty
  /// audiences, and audiences containing more than `maximumSelectorCount`
  /// unique selectors in total.
  public init(
    userIDs: [String] = [],
    teamIDs: [Int32] = [],
    teamUUIDs: [String] = [],
    roles: [WendyOrganizationRole] = []
  ) throws {
    let normalizedUserIDs = Set(userIDs.map(normalizedUserID)).sorted()
    guard normalizedUserIDs.allSatisfy(isValidUserID) else {
      throw WendyError.invalidRequest(
        "audience user IDs must contain 1...\(Self.maximumUserIDByteCount) safe ASCII bytes")
    }

    let normalizedTeamIDs = Set(teamIDs).sorted()
    guard normalizedTeamIDs.allSatisfy({ $0 > 0 }) else {
      throw WendyError.invalidRequest("audience team IDs must be positive")
    }

    let normalizedTeamUUIDs = Set(teamUUIDs.map(normalizedUserID)).sorted()
    guard normalizedTeamUUIDs.allSatisfy(isCanonicalUUID) else {
      throw WendyError.invalidRequest("audience team UUIDs must contain canonical UUIDs")
    }
    guard normalizedTeamIDs.isEmpty || normalizedTeamUUIDs.isEmpty else {
      throw WendyError.invalidRequest("audience cannot contain both team IDs and team UUIDs")
    }

    let normalizedRoles = Set(roles).sorted { $0.sortOrder < $1.sortOrder }
    let selectorCount =
      normalizedUserIDs.count + normalizedTeamIDs.count + normalizedTeamUUIDs.count
      + normalizedRoles.count
    guard selectorCount > 0 else {
      throw WendyError.invalidRequest("audience must contain at least one selector")
    }
    guard selectorCount <= Self.maximumSelectorCount else {
      throw WendyError.invalidRequest(
        "audience must contain at most \(Self.maximumSelectorCount) selectors")
    }

    self.userIDs = normalizedUserIDs
    self.teamIDs = normalizedTeamIDs
    self.teamUUIDs = normalizedTeamUUIDs
    self.roles = normalizedRoles
  }
}

private func normalizedUserID(_ userID: String) -> String {
  let withoutLeadingWhitespace = userID.drop(while: { $0.isWhitespace })
  return String(withoutLeadingWhitespace.reversed().drop(while: { $0.isWhitespace }).reversed())
}

private func isCanonicalUUID(_ value: String) -> Bool {
  guard value.utf8.count == 36 else { return false }
  for (offset, byte) in value.utf8.enumerated() {
    if offset == 8 || offset == 13 || offset == 18 || offset == 23 {
      guard byte == UInt8(ascii: "-") else { return false }
    } else {
      guard
        (byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9"))
          || (byte >= UInt8(ascii: "a") && byte <= UInt8(ascii: "f"))
      else { return false }
    }
  }
  return true
}

private func isValidUserID(_ userID: String) -> Bool {
  guard !userID.isEmpty, userID.utf8.count <= WendyAudience.maximumUserIDByteCount else {
    return false
  }
  return userID.utf8.allSatisfy {
    ($0 >= UInt8(ascii: "a") && $0 <= UInt8(ascii: "z"))
      || ($0 >= UInt8(ascii: "A") && $0 <= UInt8(ascii: "Z"))
      || ($0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9"))
      || $0 == UInt8(ascii: "-")
      || $0 == UInt8(ascii: ".")
      || $0 == UInt8(ascii: "_")
      || $0 == UInt8(ascii: ":")
  }
}

extension WendyOrganizationRole {
  fileprivate var sortOrder: Int {
    switch self {
    case .owner: 0
    case .admin: 1
    case .billingManager: 2
    case .member: 3
    case .viewer: 4
    }
  }
}
