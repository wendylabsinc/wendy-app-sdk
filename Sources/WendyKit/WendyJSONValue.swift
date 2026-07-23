/// A JSON-compatible value used by Wendy APIs.
///
/// Numbers must be finite. WendyKit rejects non-finite values before sending
/// them to WendyOS.
public indirect enum WendyJSONValue: Sendable, Hashable {
  case null
  case number(Double)
  case string(String)
  case bool(Bool)
  case object([String: WendyJSONValue])
  case array([WendyJSONValue])
}
