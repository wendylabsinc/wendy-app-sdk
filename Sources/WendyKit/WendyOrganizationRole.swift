/// A role in a Wendy organization.
@nonexhaustive
public enum WendyOrganizationRole: Sendable, Hashable {
  case owner
  case admin
  case billingManager
  case member
  case viewer
}
