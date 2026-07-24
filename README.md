# wendy-app-sdk

SDK for building **WendyOS apps** in Swift.

A WendyOS app is a `wendy run` container. This SDK gives it two things:

- **WendyKit** — typed `async`/`throws` Wendy System APIs, including
  least-privilege app-originated Notifications. WendyKit discovers the local
  WendyOS runtime and keeps its transport private. Existing administrative
  device/app/WiFi controls remain available through `WendyAgent` and continue
  to require the privileged `admin` entitlement.
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

## Send a Notification

Declare the `notifications` entitlement, then send a notification from any
async context:

```swift
import WendyKit

let response = try await WendyNotification.send(
    WendyNotificationSendRequest(
        audience: .organizationRole(.owner),
        title: "Fire detected",
        body: "Camera 2 detected smoke.",
        severity: .critical,
        deepLink: "wendy://devices/current/live?camera=2",
        sourceID: "fire-2026-07-23-001",
        metadata: try WendyNotificationMetadata(["confidence": 0.98])
    )
)

print("notified \(response.recipientCount) recipients")
```

`sourceID` is an app-generated idempotency key. Reusing it from the same app
and device returns `isDuplicate == true` without delivering the Notification
again. Metadata is optional and supports JSON-compatible nulls, booleans,
finite numbers, strings, arrays, and objects.

## Test it on a real device (WendyProbe)

The `probe/` directory is a **standalone package** with a headless,
WendyKit-only probe — no UI, so it cross-compiles and runs on a real WendyOS
device today (the WendyUI device backend is still deferred). It connects to the
live wendy-agent and prints device version, deployed apps, and WiFi
status/networks — the SDK's on-device smoke test.

It's a separate package (depending only on `WendyKit`) so SwiftCrossUI is never
in its build graph and `wendy run` builds it cleanly. From `probe/`:

    cd probe
    wendy cloud run --build-type swift --device <device-name>

Locally (no agent socket) it prints a clear "not set" message and exits 1:

    cd probe && swift run WendyProbe

See `probe/README.md` for details.

## Packaging conventions (you own these)

Declare entitlements in your app's `wendy.json`:

```json
{
  "appId": "com.example.myapp",
  "entitlements": [
    { "type": "display" },
    { "type": "notifications" }
  ]
}
```

- `notifications` → app-private Wendy System API access for
  `WendyNotification.send(_:)`. It does **not** grant administrative controls.
- `admin` → legacy `WENDY_AGENT_SOCKET` access for privileged `WendyAgent`
  device/app/WiFi controls.
- `display` → `/dev/dri` + EGL for on-device rendering.

WendyOS supplies `WENDY_SYSTEM_SOCKET` only to entitled workloads. If the
runtime is unsupported or unavailable, `send(_:)` throws
`WendyError.unavailable`; authorization failures throw
`.notificationsEntitlementRequired`.

The SDK documents these but does not generate Dockerfiles or run `wendy run`.

## On-device rendering

The device renderer, **WendyKMSBackend** — a from-scratch SwiftCrossUI
`AppBackend` over DRM/KMS + EGL/GLES with a pure-Swift, MIT-licensed TrueType
hinting text path — is delivered by a separate plan. Until it lands, WendyUI is
a macOS-dev surface. Because apps are written against SwiftCrossUI, they require
no changes when the device backend ships.

## Regenerating local API stubs

WendyKit ships pre-generated grpc-swift stubs (no `protoc` at build time). After
editing `Sources/WendyKit/Protos/`, run `./regen-agent-stubs.sh`. The Wendy
System API stubs are generated with internal visibility so apps only see the
Notification domain API, never protobuf or transport types.

## License

MIT. Dependencies: grpc-swift (Apache-2.0), SwiftProtobuf (Apache-2.0),
IkigaJSON (MIT), and SwiftCrossUI (MIT).
