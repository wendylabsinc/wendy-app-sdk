/// A role in a Wendy organization.
public enum WendyOrganizationRole: String, CaseIterable, Equatable, Sendable {
  case owner
  case admin
  case billingManager = "billing_manager"
  case member
  case viewer
}
