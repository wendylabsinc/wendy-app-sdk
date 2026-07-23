/// The users who should receive a Wendy notification.
public enum WendyAudience: Sendable, Hashable {
  /// One Wendy user.
  case user(id: String)

  /// Every member of an organization team.
  case organizationTeam(id: Int32)

  /// Every organization member with a specific role.
  case organizationRole(WendyOrganizationRole)
}
