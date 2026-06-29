// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "wendy-app-sdk",
    platforms: [.macOS(.v15)], // grpc-swift v2 transport requires macOS 15 (dev only; device is Linux)
    products: [
        .library(name: "WendyKit", targets: ["WendyKit"]),
        .library(name: "WendyUI", targets: ["WendyUI"]),
        .executable(name: "HelloWendy", targets: ["HelloWendy"]),
    ],
    dependencies: [
        .package(url: "https://github.com/grpc/grpc-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/grpc/grpc-swift-protobuf", from: "1.0.0"),
        .package(url: "https://github.com/grpc/grpc-swift-nio-transport", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-protobuf", from: "1.28.0"),
        .package(url: "https://github.com/stackotter/swift-cross-ui", .upToNextMinor(from: "0.7.0")),
    ],
    targets: [
        .target(
            name: "WendyKit",
            dependencies: [
                .product(name: "GRPCCore", package: "grpc-swift"),
                .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
                .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ]
            // Protos/ + codegen config are added (and excluded) in Task 2.
        ),
        .target(
            name: "WendyUI",
            dependencies: [
                "WendyKit",
                .product(name: "SwiftCrossUI", package: "swift-cross-ui"),
                .product(name: "DefaultBackend", package: "swift-cross-ui"),
            ]
        ),
        .executableTarget(
            name: "HelloWendy",
            dependencies: ["WendyKit", "WendyUI"]
        ),
        .testTarget(name: "WendyKitTests", dependencies: ["WendyKit"]),
        .testTarget(name: "HelloWendyTests", dependencies: ["HelloWendy"]),
    ]
)
