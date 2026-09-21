# Design

## Context

The project provisions a WireGuard VPN on Azure via Terraform + cloud-init. All peer configuration is done inside `templates/cloud-init.yaml.tftpl` through two bash scripts: `init-wireguard.sh` (first peer, runs at boot) and `add-wg-client` (subsequent peers, run manually via SSH). See `proposal.md – Why` for the quantum threat motivation.

WireGuard already has built-in support for a `PresharedKey` (PSK) per peer in its protocol (section 5.4 of the WireGuard paper). The PSK is XOR-mixed into the chaining key during the handshake, adding a 256-bit symmetric layer on top of the Curve25519 ECDH. Breaking a session requires compromising both the elliptic-curve exchange *and* the symmetric key — the latter is not vulnerable to Shor's algorithm.

## Goals / Non-Goals

**Goals:**
- Generate a unique 256-bit PSK per peer via `wg genpsk`
- Store each PSK at `/etc/wireguard/<name>_psk.key` (0600, root:root)
- Inject PSK into both the server `[Peer]` block and the client `[Interface]`→`[Peer]` block
- Cover both `init-wireguard.sh` (client1 at boot) and `add-wg-client` (runtime clients)

**Non-Goals:**
- Upgrading to a post-quantum key encapsulation mechanism (ML-KEM / Kyber) — this requires a patched WireGuard kernel module or `wireguard-go`, introduces significant complexity and is not yet in mainline Linux; PSK is the IETF/WireGuard-recommended mitigation for now
- Rotating PSKs automatically — out of scope; PSKs are stable per peer like private keys
- Retrofitting PSKs onto already-provisioned VMs — re-provision to get PSK support; no in-place migration path defined

## Decisions

### D1: Use WireGuard's built-in `PresharedKey` rather than a patched kernel module

**Decision**: Add `PresharedKey` to each peer via `wg genpsk`. Do not use OQS-WireGuard, wireguard-go with post-quantum patches, or any kernel module replacement.

**Why**: The PSK mechanism is part of the WireGuard spec and is available in the stock Ubuntu kernel. It provides the quantum-resistant symmetric layer without any kernel patching, custom binaries, or maintenance burden. The alternative — OQS-WireGuard (OpenQuantumSafe fork) — requires building a custom kernel or userspace daemon, is not packaged for Ubuntu, and is experimental. For a single-VM VPN setup the PSK approach is the correct risk/complexity tradeoff.

**Cryptographic note**: A 256-bit PSK means an attacker with a quantum computer must still brute-force a 128-bit effective symmetric key space (Grover's algorithm halves symmetric key strength) — which remains computationally infeasible for the foreseeable future.

### D2: One PSK per peer (not one shared PSK for all peers)

**Decision**: Each peer gets its own independently generated PSK stored in a separate file.

**Why**: A single shared PSK across all peers means that any client compromise exposes the quantum-resistant layer for all other sessions. Per-peer PSKs provide isolation. The storage and generation overhead is trivial (`wg genpsk` is one command per peer).

### D3: PSK stored in `/etc/wireguard/<name>_psk.key` (same pattern as private keys)

**Decision**: Follow the existing key naming convention in `init-wireguard.sh`: `server_private.key`, `client1_private.key` → `client1_psk.key`.

**Why**: Consistent, predictable, easy to audit. The directory is already `chmod 700`; files are `chmod 600` root-owned. No new storage location or secret manager needed. PSK values are sensitive (but not as sensitive as private keys — a PSK alone does not let an attacker impersonate) and warrant the same file-level protection.

### D4: PSK is embedded in the distributed client `.conf` file

**Decision**: The client's `[Peer]` block in its `.conf` file contains `PresharedKey = <value>` inline, exactly as WireGuard expects.

**Why**: WireGuard clients need the PSK to complete a handshake with a PSK-configured server peer. There is no alternative transport for it — it must be in the config. The client config is already a sensitive file (contains the private key); adding the PSK does not change the threat model.

### D5: `wg set` live update includes PSK when adding peer dynamically

**Decision**: In `add-wg-client`, the `wg set wg0 peer ... allowed-ips ...` call is extended to include `preshared-key <(echo "$CLIENT_PSK")` using process substitution so the PSK is passed to the kernel interface without touching disk as a plain argument.

**Why**: `wg set` accepts `preshared-key <file-descriptor>` to avoid exposing the key in `/proc/<pid>/cmdline`. Using process substitution (`<(echo ...)`) keeps the key out of the shell's argument list.

## Risks / Trade-offs

- **PSK distribution is as sensitive as private key distribution** → The client `.conf` already contains the private key, so no new risk surface is added. Same secure transfer advice applies (e.g., QR code scan over an in-person or encrypted channel).
- **Existing peers on a re-provisioned server will not have matching PSKs** → The server generates new keys on every provision. All clients must re-import configs after re-provisioning regardless; PSK adds nothing new here.
- **`wg set` preshared-key via process substitution may not work in all shell environments** → This is bash-specific. The cloud-init scripts already use `#!/usr/bin/env bash` with `set -euo pipefail`, so process substitution is available. Fallback: write PSK to a temp file, pass path to `wg set`, then `shred` the temp file.
- **Grover's algorithm reduces PSK security from 256-bit to ~128-bit effective** → 128-bit symmetric security is considered sufficient against quantum adversaries for the foreseeable future (NIST recommends 128-bit post-quantum security level).

## Migration Plan

Applies to newly provisioned VMs only (Terraform destroy + apply). Existing deployed VMs:
- Continue working with existing configs (no PSK)
- Are not quantum-resistant until re-provisioned
- No in-place upgrade path is defined in this change
