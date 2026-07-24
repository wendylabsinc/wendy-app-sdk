import Foundation
import IkigaJSON

/// App-defined JSON metadata attached to a Wendy notification.
///
/// Metadata owns a normalized JSON representation so it remains safely
/// `Sendable` even though `JSONObject` itself is mutable and not `Sendable`.
public struct WendyNotificationMetadata: Sendable, Hashable {
  private let json: String

  /// Creates metadata by taking an immutable snapshot of a JSON object.
  ///
  /// Object keys are normalized so equality and hashing are independent of
  /// insertion order. Non-finite numbers and unsupported custom `JSONValue`
  /// conformances are rejected.
  public init(_ object: JSONObject) throws {
    self.json = try normalized(object).string
  }

  /// Creates metadata from JSON-compatible values.
  public init(_ values: [String: any JSONValue]) throws {
    var object = JSONObject()
    for (key, value) in values {
      object[key] = try normalized(value)
    }
    try self.init(object)
  }

  /// Returns a mutable JSON object containing an independent copy of the
  /// metadata.
  public func jsonObject() throws -> JSONObject {
    try JSONObject(data: Data(json.utf8))
  }
}

private func normalized(_ object: JSONObject) throws -> JSONObject {
  var result = JSONObject()
  for key in object.keys.sorted() {
    guard let value = object[key] else { continue }
    result[key] = try normalized(value)
  }
  return result
}

private func normalized(_ array: JSONArray) throws -> JSONArray {
  var result = JSONArray()
  for value in array {
    result.append(try normalized(value))
  }
  return result
}

private func normalized(_ value: any JSONValue) throws -> any JSONValue {
  switch value {
  case let value as JSONObject:
    return try normalized(value)
  case let value as JSONArray:
    return try normalized(value)
  case let value as Bool:
    return value
  case let value as String:
    return value
  case let value as Int:
    return value
  case let value as Double:
    guard value.isFinite else {
      throw WendyError.invalidRequest("metadata numbers must be finite")
    }
    return value
  case is NSNull:
    return NSNull()
  default:
    throw WendyError.invalidRequest("metadata contains an unsupported JSON value")
  }
}
