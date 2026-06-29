# wendy-app-sdk

SDK for building **WendyOS apps** in Swift.

A WendyOS app is a `wendy run` container. This SDK gives it two things:

- **WendyKit** — a typed `async`/`throws` client for **wendy-agent** over its
  local unix socket (`WENDY_AGENT_SOCKET`, provided by the `admin` entitlement):
  device version, deployed apps, WiFi networks/status, and more as the agent's
  API grows. Calls throw on failure; socket-absent is a distinct, non-throwing
  signal (`WendyAgent.fromEnvironment() == nil`).
- **WendyUI** — a SwiftUI-like declarative UI built on
  [SwiftCrossUI](https://github.com/stackotter/swift-cross-ui) (MIT). No web
  browser, no `.slint`, no C++. On macOS it renders via AppKit for development.

## Quick start

    .package(url: "<this repo>", branch: "main")

```swift
import WendyUI
import WendyKit

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup("MyApp") { Text("Hello from WendyOS") }
    }
}
```

See `Sources/HelloWendy/` for a complete example.

## Packaging conventions (you own these)

Declare entitlements in your app's `wendy.json`:

```json
{ "appId": "com.example.myapp",
  "entitlements": [ { "type": "gpu" }, { "type": "admin" } ] }
```

- `admin` → `WENDY_AGENT_SOCKET` for WendyKit.
- `gpu`   → `/dev/dri` + EGL for on-device rendering.

The SDK documents these but does not generate Dockerfiles or run `wendy run`.

## On-device rendering

The device renderer, **WendyKMSBackend** — a from-scratch SwiftCrossUI
`AppBackend` over DRM/KMS + EGL/GLES with a pure-Swift, MIT-licensed TrueType
hinting text path — is delivered by a separate plan. Until it lands, WendyUI is
a macOS-dev surface. Because apps are written against SwiftCrossUI, they require
no changes when the device backend ships.

## Regenerating agent stubs

WendyKit ships pre-generated grpc-swift stubs (no `protoc` at build time). After
editing `Sources/WendyKit/Protos/`, run `./regen-agent-stubs.sh` (needs `protoc`
+ `protoc-gen-swift`; builds `protoc-gen-grpc-swift` from resolved deps).

## License

MIT. Dependencies: grpc-swift (Apache-2.0), SwiftProtobuf (Apache-2.0),
SwiftCrossUI (MIT).
