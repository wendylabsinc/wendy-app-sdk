// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "wendy-app-sdk",
    platforms: [.macOS(.v15)], // grpc-swift v2 transport requires macOS 15 (dev only; device is Linux)
    products: [
        .library(name: "WendyKit", targets: ["WendyKit"]),
        .library(name: "WendyUI", targets: ["WendyUI"]),
        .executable(name: "HelloWendy", targets: ["HelloWendy"]),
        // Headless on-device probe: depends on WendyKit only (no UI), so it
        // builds and runs on a real WendyOS device. Build just this product to
        // avoid compiling WendyUI/SwiftCrossUI: `swift build --product WendyProbe`.
        .executable(name: "WendyProbe", targets: ["WendyProbe"]),
    ],
    dependencies: [
        .package(url: "https://github.com/grpc/grpc-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/grpc/grpc-swift-protobuf", from: "1.0.0"),
        .package(url: "https://github.com/grpc/grpc-swift-nio-transport", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-protobuf", from: "1.28.0"),
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
            ],
            // Stubs are pre-generated into Generated/ (committed); .proto sources +
            // codegen config are kept for regeneration but excluded from the build,
            // so no protoc is needed at build time. Regenerate with regen-agent-stubs.sh.
            exclude: ["Protos", "grpc-swift-proto-generator-config.json"]
        ),
        // WendyUI is Apple-platform-only for now: SwiftCrossUI's DefaultBackend
        // has no Linux backend without a display server (the device renderer,
        // WendyKMSBackend, is a separate plan). Gating the SwiftCrossUI deps to
        // Apple platforms — paired with `#if canImport(SwiftCrossUI)` in the
        // sources — keeps the package Linux-buildable so WendyKit + WendyProbe
        // build for the device. On Linux, WendyUI is an empty module.
        .target(
            name: "WendyUI",
            dependencies: [
                "WendyKit",
                .product(name: "SwiftCrossUI", package: "swift-cross-ui", condition: .when(platforms: [.macOS, .iOS, .tvOS, .visionOS])),
                .product(name: "DefaultBackend", package: "swift-cross-ui", condition: .when(platforms: [.macOS, .iOS, .tvOS, .visionOS])),
            ]
        ),
        .executableTarget(
            name: "HelloWendy",
            dependencies: [
                "WendyKit",
                "WendyUI",
                .product(name: "SwiftCrossUI", package: "swift-cross-ui", condition: .when(platforms: [.macOS, .iOS, .tvOS, .visionOS])),
                .product(name: "DefaultBackend", package: "swift-cross-ui", condition: .when(platforms: [.macOS, .iOS, .tvOS, .visionOS])),
            ],
            exclude: ["wendy.json", "README.md"]
        ),
        .executableTarget(
            name: "WendyProbe",
            dependencies: ["WendyKit"]
        ),
        .testTarget(name: "WendyKitTests", dependencies: ["WendyKit"]),
        .testTarget(name: "HelloWendyTests", dependencies: ["HelloWendy"]),
    ]
)
