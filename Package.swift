// swift-tools-version: 6.3.2
import PackageDescription

let package = Package(
    name: "wendy-app-sdk",
    platforms: [.macOS(.v15)], // grpc-swift v2 transport requires macOS 15 (dev only; device is Linux)
    products: [
        .library(name: "WendyKit", targets: ["WendyKit"]),
        .library(name: "WendyUI", targets: ["WendyUI"]),
        .library(name: "WendyTextKit", targets: ["WendyTextKit"]),
        .library(name: "WendyCanvas", targets: ["WendyCanvas"]),
        .library(name: "WendyKMSDRM", targets: ["WendyKMSDRM"]),
        .library(name: "WendyKMSInput", targets: ["WendyKMSInput"]),
        .library(name: "WendyKMSBackend", targets: ["WendyKMSBackend"]),
        .library(name: "MeshFanout", targets: ["MeshFanout"]),
        .executable(name: "HelloWendy", targets: ["HelloWendy"]),
        // The headless on-device probe lives in its own package under `probe/`
        // (depends on WendyKit only, no SwiftCrossUI) so it cross-compiles and
        // `wendy run`s cleanly for the device. See probe/README.md.
    ],
    dependencies: [
        .package(url: "https://github.com/grpc/grpc-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/grpc/grpc-swift-protobuf", from: "1.0.0"),
        .package(url: "https://github.com/grpc/grpc-swift-nio-transport", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-protobuf", from: "1.28.0"),
        .package(url: "https://github.com/orlandos-nl/swift-json.git", from: "2.5.3"),
        .package(url: "https://github.com/stackotter/swift-cross-ui", .upToNextMinor(from: "0.7.0")),
        .package(url: "https://github.com/apple/swift-container-plugin", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "WendyKit",
            dependencies: [
                .product(name: "GRPCCore", package: "grpc-swift"),
                .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
                .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "IkigaJSON", package: "swift-json"),
            ],
            // Stubs are pre-generated into Generated/ (committed); .proto sources +
            // codegen config are kept for regeneration but excluded from the build,
            // so no protoc is needed at build time. Regenerate with regen-agent-stubs.sh.
            exclude: ["Protos", "grpc-swift-proto-generator-config.json"]
        ),
        // WendyUI is the app UI entry point. Backend selection is per platform:
        //   - macOS/iOS/tvOS/visionOS: AppKit (via SwiftCrossUI's DefaultBackend)
        //   - Linux (device): WendyKMSBackend — our from-scratch DRM/KMS backend
        // SwiftCrossUI itself is pulled on all platforms; DefaultBackend is Apple-only.
        .target(
            name: "WendyUI",
            dependencies: [
                "WendyKit",
                .product(name: "SwiftCrossUI", package: "swift-cross-ui"),
                .product(name: "DefaultBackend", package: "swift-cross-ui", condition: .when(platforms: [.macOS, .iOS, .tvOS, .visionOS])),
                .target(name: "WendyKMSBackend", condition: .when(platforms: [.linux])),
            ]
        ),
        .executableTarget(
            name: "HelloWendy",
            dependencies: [
                "WendyKit",
                "WendyUI",
            ],
            exclude: ["wendy.json", "README.md"]
        ),
        .target(name: "CStbTrueType"),
        .target(name: "CWendyFont"),
        .target(
            name: "WendyTextKit",
            dependencies: ["CStbTrueType", "CWendyFont"],
            // Font and license kept on disk for provenance; no longer SwiftPM resources.
            exclude: ["Resources"],
            // Always optimize the software renderer, even in debug builds. These
            // targets are tight per-pixel/per-glyph loops; unoptimized they push a
            // full-screen redraw to ~600ms (≈1.6 fps) on device. `wendy run` cross-
            // compiles the container image in debug, so without this the on-device
            // UI is unusably slow. Allowed because consumers depend on this package
            // by path, not by version.
            swiftSettings: [.unsafeFlags(["-O"])]
        ),
        .target(
            name: "WendyCanvas",
            dependencies: ["WendyTextKit"],
            swiftSettings: [.unsafeFlags(["-O"])]  // see WendyTextKit: optimize the renderer in all configs
        ),
        .target(
            name: "WendyKMSDRM",
            cSettings: [
                .headerSearchPath("vendor"),
                // The sysroot's uapi drm.h uses `__user` (a kernel annotation)
                // that is not defined in Debian bookworm's userspace headers.
                // Define it as empty so the vendored UAPI headers compile cleanly.
                .define("__user", to: ""),
            ]
        ),
        .target(name: "WendyKMSInput"),
        .target(name: "MeshFanout"),
        .target(
            name: "WendyKMSBackend",
            dependencies: [
                "WendyCanvas", "WendyTextKit", "WendyKMSDRM", "WendyKMSInput",
                .product(name: "SwiftCrossUI", package: "swift-cross-ui"),
            ],
            swiftSettings: [
                // SwiftCrossUI is compiled with swift-tools-version 5.10; its
                // BackendFeatures.Core protocol uses @MainActor closures whose
                // sendability is interpreted differently by Swift 6 strict
                // concurrency. Building this target in Swift 5 mode avoids the
                // cross-module sendability mismatch while keeping the rest of the
                // package in Swift 6 mode.
                .swiftLanguageMode(.v5),
                // Optimize the backend's render loop even in debug (see WendyTextKit).
                .unsafeFlags(["-O"]),
            ]
        ),
        .testTarget(name: "WendyKMSBackendTests", dependencies: ["WendyKMSBackend"]),
        .testTarget(name: "WendyKitTests", dependencies: ["WendyKit"]),
        .testTarget(name: "HelloWendyTests", dependencies: ["HelloWendy"]),
        .testTarget(name: "WendyTextKitTests", dependencies: ["WendyTextKit"]),
        .testTarget(name: "WendyCanvasTests", dependencies: ["WendyCanvas", "WendyTextKit"]),
        .testTarget(name: "MeshFanoutTests", dependencies: ["MeshFanout"]),
    ]
)
