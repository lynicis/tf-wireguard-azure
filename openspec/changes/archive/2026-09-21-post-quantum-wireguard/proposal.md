# Proposal

## Why

WireGuard's key exchange uses Curve25519 (ECDH), which a sufficiently powerful quantum computer could break using Shor's algorithm, exposing all recorded session traffic retroactively ("harvest now, decrypt later"). Adding a post-quantum pre-shared key (PSK) layer per peer — using WireGuard's built-in `PresharedKey` mechanism — makes each session's key derivation quantum-resistant today with no changes to the WireGuard protocol, kernel module, or kernel version, and at near-zero operational overhead.

## What Changes

- Generate a unique 256-bit pre-shared key (`wg genpsk`) per WireGuard peer during server initialization and client creation
- Embed the PSK in both the server's `[Peer]` block (`PresharedKey = ...`) and the matching client's `[Peer]` block (`PresharedKey = ...`)
- Update the `init-wireguard.sh` script (initial `client1`) to generate, store, and inject a PSK
- Update the `add-wg-client` script (subsequent clients) to generate, store, and inject a PSK per new peer
- Store PSK files on the server at `/etc/wireguard/<client-name>_psk.key` with `0600` permissions (same pattern as existing private keys)
- PSK values are embedded in the client `.conf` files distributed to users — no additional out-of-band exchange step

## Capabilities

### New Capabilities

_(none — this strengthens the existing VPN session security without introducing a new user-facing capability)_

### Modified Capabilities

- `wireguard-server`: Key exchange requirement changes — each peer MUST have a `PresharedKey` in both its server-side `[Peer]` block and its client-side `[Peer]` block; PSKs SHALL be generated with `wg genpsk` and stored on the server; peer configurations without a PSK SHALL NOT be created

## Impact

- `templates/cloud-init.yaml.tftpl`: both `init-wireguard.sh` and `add-wg-client` heredocs updated to call `wg genpsk`, store the key, and write it into both sides of the peer config
- No changes to `main.tf`, `variables.tf`, `outputs.tf`, or any Terraform resource
- Existing peer configurations are not quantum-resistant until re-provisioned; clients with old configs continue to connect (PSK is additive, not enforced by the server against peers that don't have one — but the spec will require all newly generated peers to include one)
- No new dependencies, packages, or kernel requirements — `wg genpsk` ships with `wireguard-tools`, already installed
