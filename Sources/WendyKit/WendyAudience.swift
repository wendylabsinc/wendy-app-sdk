/// The users who should receive a Wendy notification.
public enum WendyAudience: Equatable, Sendable {
  /// One Wendy user.
  case user(id: String)

  /// Every member of an organization team.
  case team(id: Int)

  /// Every organization member with a specific role.
  case organizationRole(WendyOrganizationRole)
}
