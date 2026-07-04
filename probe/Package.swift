// swift-tools-version: 6.0
import PackageDescription

// Standalone package for the headless on-device probe. It depends ONLY on the
// SDK's WendyKit product (via the parent package by path), so SwiftCrossUI is
// never in its build graph — meaning `wendy run` / `swift build` here
// cross-compile cleanly for the WendyOS (Linux) device. The parent's WendyUI
// and its SwiftCrossUI dependency are not reachable from this package.
let package = Package(
    name: "wendy-app-sdk-probe",
    platforms: [.macOS(.v15)], // grpc-swift v2 transport requires macOS 15 (dev only; device is Linux)
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/apple/swift-container-plugin", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "WendyProbe",
            dependencies: [
                .product(name: "WendyKit", package: "wendy-app-sdk"),
            ]
        ),
        .executableTarget(
            name: "KMSDrawProbe",
            dependencies: [
                .product(name: "WendyKMSDRM", package: "wendy-app-sdk"),
                .product(name: "WendyCanvas", package: "wendy-app-sdk"),
                .product(name: "WendyTextKit", package: "wendy-app-sdk"),
            ]
        ),
        .executableTarget(name: "TickDemo", dependencies: [.product(name: "WendyUI", package: "wendy-app-sdk")]),
        .executableTarget(name: "DashboardDemo", dependencies: [
            .product(name: "WendyUI", package: "wendy-app-sdk"),
            .product(name: "WendyKit", package: "wendy-app-sdk"),
        ]),
        .executableTarget(name: "AppControlDemo", dependencies: [
            .product(name: "WendyUI", package: "wendy-app-sdk"),
            .product(name: "WendyKit", package: "wendy-app-sdk"),
        ]),
        .executableTarget(
            name: "RemoteCamViewer",
            dependencies: [
                .product(name: "WendyKMSDRM", package: "wendy-app-sdk"),
                .product(name: "WendyCanvas", package: "wendy-app-sdk"),
                .product(name: "WendyTextKit", package: "wendy-app-sdk"),
                .product(name: "WendyKMSInput", package: "wendy-app-sdk"),
            ]
        ),
        .executableTarget(
            name: "MeshBeacon",
            dependencies: [
                .product(name: "WendyKMSDRM", package: "wendy-app-sdk"),
                .product(name: "WendyCanvas", package: "wendy-app-sdk"),
                .product(name: "WendyTextKit", package: "wendy-app-sdk"),
                .product(name: "WendyKMSInput", package: "wendy-app-sdk"),
                .product(name: "MeshFanout", package: "wendy-app-sdk"),
            ]
        ),
    ]
)
