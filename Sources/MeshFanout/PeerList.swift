import Foundation

/// Parses a MESH_PEERS-style env var value ("comma-separated asset IDs, e.g.
/// "270,271,272") into mesh hostnames ("device-270.cloud.wendy.dev", ...).
/// Blank entries (an empty string, a trailing comma, or all-whitespace) are
/// skipped rather than turned into a malformed "device-.cloud.wendy.dev"
/// hostname. `selfID`, if non-empty, is excluded from the result so a
/// device's own asset ID in a shared MESH_PEERS value (the same list handed
/// to every fleet member, matching Examples/HelloMesh's convention) doesn't
/// make it dial itself.
public func parseMeshPeers(_ raw: String, excluding selfID: String = "") -> [String] {
    let trimmedSelf = selfID.trimmingCharacters(in: .whitespaces)
    return raw.split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty && $0 != trimmedSelf }
        .map { "device-\($0).cloud.wendy.dev" }
}
