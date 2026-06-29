// WendyUI is the WendyOS app UI layer. App authors `import WendyUI` and write
// SwiftCrossUI views (App / Scene / View) — no .slint, no C++.
//
// Backend selection is compile-time via SwiftCrossUI's DefaultBackend:
//   - macOS (dev): AppKitBackend
//   - device (Linux/linuxkms): WendyKMSBackend — a from-scratch DRM/KMS backend
//     delivered by a separate plan; not present yet. Until then, device builds
//     have no backend and this module is dev-only.
//
// Re-exporting both means a WendyOS app needs only `import WendyUI`.
//
// SwiftCrossUI is Apple-platform-only here (see Package.swift): on Linux it has
// no usable backend yet, so on Linux WendyUI is an empty module and the package
// still builds for the device (WendyKit + WendyProbe).
#if canImport(SwiftCrossUI)
@_exported import SwiftCrossUI
@_exported import DefaultBackend
#endif
