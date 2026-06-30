// WendyUI: SwiftCrossUI for app authors; backend chosen per platform.
//
// Backend selection:
//   - macOS / iOS / tvOS / visionOS: AppKit (DefaultBackend, re-exported here)
//   - Linux (device): WendyKMSBackend (re-exported here; `App.Backend` typealias
//     lives in WendyKMSBackend.swift — LVGLBackend pattern — so we do NOT repeat
//     it here to avoid a "redundant conformance" error).
//
// App authors need only `import WendyUI` — no backend import required.
@_exported import SwiftCrossUI

#if canImport(DefaultBackend)
@_exported import DefaultBackend
#elseif canImport(WendyKMSBackend)
@_exported import WendyKMSBackend
#endif
