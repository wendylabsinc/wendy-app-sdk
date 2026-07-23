/// App-defined JSON metadata attached to a Wendy notification.
public struct WendyNotificationMetadata: Sendable, Hashable {
  public let values: [String: WendyJSONValue]

  public init(_ values: [String: WendyJSONValue]) {
    self.values = values
  }
}

// MARK: - ExpressibleByDictionaryLiteral

extension WendyNotificationMetadata: ExpressibleByDictionaryLiteral {
  public init(dictionaryLiteral elements: (String, WendyJSONValue)...) {
    self.init(Dictionary(uniqueKeysWithValues: elements))
  }
}
