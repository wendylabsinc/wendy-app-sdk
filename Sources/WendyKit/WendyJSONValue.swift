/// A JSON-compatible value used by Wendy APIs.
///
/// Numbers must be finite. WendyKit rejects non-finite values before sending
/// them to WendyOS.
public indirect enum WendyJSONValue: Equatable, Sendable {
  case null
  case bool(Bool)
  case number(Double)
  case string(String)
  case array([WendyJSONValue])
  case object([String: WendyJSONValue])
}
