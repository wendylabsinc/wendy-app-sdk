# WendyProbe — headless on-device SDK probe

A standalone WendyOS app that exercises **WendyKit** against the live wendy-agent
and prints device version, deployed apps, and WiFi status/networks. It's the
SDK's on-device smoke test.

This is its **own package** (depends only on `WendyKit` via the parent SDK by
path), so it has no SwiftCrossUI in its build graph and cross-compiles cleanly
for the device — unlike the macOS-only UI sample (`../Sources/HelloWendy`).

## Run on a device

From this directory:

    wendy cloud run --build-type swift --device <device-name>

There's a single executable product, so no `--product` flag is needed. The
`wendy.json` here declares the `admin` entitlement, which bind-mounts
`WENDY_AGENT_SOCKET` so `WendyKit` can reach the agent.

## Run locally (no device)

    swift run WendyProbe

With no agent socket present it prints a clear "not set" message and exits 1.

## Expected device output

```
=== wendy-app-sdk probe ===
agent socket: /run/wendy/agent.sock

[device version]
  os:    wendyos WendyOS-0.16.0
  agent: 2026.06.29-143514
  arch:  arm64
  type:  jetson-orin-nano
  gpu:   yes

[apps]
  - sh.wendy.shell latest [running]
  ...

[wifi status]
  connected to <SSID>
=== probe complete ===
```

## Other demo apps in this package

This package also hosts several standalone display/mesh demo apps (each with
its own `wendy.json` here and its own executable target under `Sources/`) —
see [`MESH_DEMOS.md`](./MESH_DEMOS.md) for MeshBeacon and MeshCounter, the
mesh showcase pair.
