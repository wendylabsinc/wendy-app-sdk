# Mesh showcase demos: MeshBeacon + MeshCounter

Two small on-device apps that show off the WendyOS mesh data plane's
**one-to-many** pattern: every device runs the identical app, taps fan out to
every peer, and every peer reacts. (Contrast with
[RemoteCamViewer](./Sources/RemoteCamViewer), which is a directed 1:1 pair.)

| Demo | What a tap does | Demonstrates |
| --- | --- | --- |
| [MeshBeacon](./Sources/MeshBeacon) | Broadcasts this device's color; every peer (and the sender itself) flashes that color for 1s | Pub/sub fan-out |
| [MeshCounter](./Sources/MeshCounter) | Broadcasts a +1; every peer increments its own shared counter | Simple shared-state sync |

Both apps are built on **MeshFanout** (`../Sources/MeshFanout`), a small
shared Swift library with no dependencies beyond Foundation:

- `parseMeshPeers(_:excluding:)` — turns a `MESH_PEERS` env var
  (`"270,271,272"`) into mesh hostnames, skipping this device's own ID.
- `MeshFanout` — listens on a TCP port for inbound frames and
  `broadcast(type:payload:)`s a frame to every configured peer. Fire-and-forget,
  one connection per message, no delivery confirmation — a slow or
  unreachable peer never blocks the others or the caller.
- A tiny wire format, reused from RemoteCamViewer's own protocol:
  `[1-byte type][4-byte big-endian length][payload]`.

Both apps reuse the same raw KMS-display + evdev-touch stack RemoteCamViewer
already proved on real hardware (no SwiftCrossUI in either build graph).

## What it demonstrates

Each app declares a `network` entitlement in `mesh` mode plus a published
port, e.g. MeshBeacon's `wendy.json` service:

```json
{
    "type": "network",
    "mode": "mesh",
    "serviceCIDR": "10.99.0.0/16",
    "ports": [{ "host": 9091, "container": 9091 }]
}
```

- `mode: "mesh"` grants the container egress to the mesh service CIDR, so it
  can dial every peer in `MESH_PEERS`.
- `ports` publishes the container's listen port, so peers can reach this
  device at `device-<idOfThisDevice>.cloud.wendy.dev:<port>`.
- `isolation: "isolated"` (top-level, in both `wendy.json` files) is required
  for the mesh route to have a network namespace to live in — see the
  `wendyos-mesh` repo's `Examples/HelloMesh/README.md` ("Why isolation:
  isolated") for the full explanation.

MeshBeacon listens on **9091**, MeshCounter on **9092** — different ports so
both can run side by side on the same fleet without colliding.

## Wire format

| App | Type byte | Payload | Meaning |
| --- | --- | --- | --- |
| MeshBeacon | `0x01` | 3 bytes: `[r][g][b]` | flash the screen this color |
| MeshCounter | `0x02` | *(none)* | +1 to the shared counter |

MeshCounter's message carries no payload at all — every operation is "+1",
so the message type alone is the entire message. This makes MeshCounter's
sync a pure-addition CRDT: commutative, so delivery order across peers never
matters and there is no conflict resolution to write. Neither demo persists
state or catches a peer up on join — a freshly-started device starts at
count 0 / idle, unaware of what happened before it joined.

## Run it

Both apps live in this SDK's `probe/` package but — unlike the other probe
apps — build via a Dockerfile instead of the Swift buildpack, because they're
built from the **repo root** (`wendy-app-sdk/`), not from `probe/` alone (so
the build can see both `Sources/MeshFanout` and `probe/Sources/<App>`).
Deploying one is a two-file swap-in, from the repo root:

```bash
cd wendy-app-sdk

# Pick one app - MeshBeacon:
cp probe/meshbeacon.wendy.json wendy.json
cp Dockerfile.meshbeacon Dockerfile

# Find your devices' asset IDs (numbers, 1-65534):
wendy cloud discover --json   # the "id" field per device

# Deploy to each device in the fleet, setting MESH_SELF/MESH_PEERS per device:
MESH_SELF=270 MESH_PEERS=270,271 wendy run --device <device-1>
MESH_SELF=271 MESH_PEERS=270,271 wendy run --device <device-2>
```

Swap `meshbeacon` for `meshcounter` (and the port in `MESH_PEERS` entries, if
you override the default) to run the other demo instead. `wendy.json` and
`Dockerfile` at the repo root are both gitignored/restored-after-use — after
a deploy, `git checkout -- wendy.json` and `rm Dockerfile` return the repo to
a clean state before committing anything else.

`MESH_PEERS` accepts bare asset IDs (`270`), which expand to
`device-270.cloud.wendy.dev`; `MESH_SELF` is excluded from its own peer list
automatically, so it's safe to pass the same `MESH_PEERS` value to every
device in the fleet.

## Expected output

```
[meshbeacon] self=270 peers=[device-271.cloud.wendy.dev]
[meshbeacon] listening on port 9091
[meshbeacon] opening /dev/dri/card0 (stop sh.wendy.shell first so KMS is free)
[meshbeacon] display 1920x1080 stride=7680
[meshbeacon] ready; tap anywhere to send a beacon
[meshbeacon] sending beacon (color=0x3e7ae5)
```

```
[meshcounter] self=270 peers=[device-271.cloud.wendy.dev]
[meshcounter] listening on port 9092
[meshcounter] opening /dev/dri/card0 (stop sh.wendy.shell first so KMS is free)
[meshcounter] display 1920x1080 stride=7680
[meshcounter] ready; tap anywhere for +1
```

## Hardware verification status

Both apps are hardware-verified end to end on a Raspberry Pi 5 (KMS display +
evdev touch + real mesh broadcasts) and verified at the network/protocol
level against a Jetson AGX Orin peer — exact expected byte counts over real
mesh connections, zero failures even under a rapid 89-tap burst on
MeshCounter. The Orin's own on-screen confirmation is blocked by an
unrelated, already-diagnosed NVIDIA Tegra DRM limitation
(`wendy_kms_open` fails with `GETRESOURCES count: Operation not supported` —
needs `nvidia-drm.modeset=1` on the kernel boot command line, a separate
OS/build-level fix, out of scope for these apps).

## Debugging tips

- Screen stays idle after a tap on every device, including the sender: check
  the tapping device's own logs for `sending beacon` / the increment path —
  if that line never appears, the touch coordinates aren't landing inside
  the app (there's no "button" in either demo, the whole screen is the
  target, so this usually means the touch device isn't open — look for
  `touch input unavailable` in the logs).
- Sender flashes/increments locally but peers never react: same mesh
  plumbing checks as HelloMesh apply — see the `wendyos-mesh` repo's
  `Examples/HelloMesh/README.md` ("Debugging the plumbing" section: iptables
  `WENDY-MESH` chain, `nsenter`-based route check, etc). Also confirm both
  devices' agents support `MeshDial` — an older agent on either side breaks
  the dial.
- `wendy_kms_open failed: ...` truncated in the logs: shouldn't happen after
  this branch's flush-before-exit fix, but if it recurs on a new failure
  path, stdout is block-buffered off a TTY — call `wendy_kms_flush_stdout()`
  immediately before any `exit()` that follows a log line.
- `wendy_kms_open failed: GETRESOURCES count: Operation not supported` on a
  Jetson/Tegra device: known DRM/KMS driver limitation, not a bug in this
  app — the device's kernel boot args need `nvidia-drm.modeset=1`.
