# HelloWendy

Sample WendyOS app using the wendy-app-sdk.

- `WendyKit` — talks to wendy-agent (device version, apps) over `WENDY_AGENT_SOCKET`.
- `WendyUI` — SwiftCrossUI UI; renders via AppKit on macOS for development.

## Run on macOS (dev)

    swift run HelloWendy

No agent socket is present on a plain Mac, so the app uses `SampleProvider`.

## On-device packaging (conventions; not built by the SDK)

Declare entitlements in `wendy.json`:
- `admin` → `WENDY_AGENT_SOCKET` is bind-mounted, so `WendyAgent.fromEnvironment()` returns a live client.
- `gpu`   → `/dev/dri` + EGL for the device renderer (`WendyKMSBackend`, separate plan).

Building the container image and `wendy run` are the app author's responsibility.
