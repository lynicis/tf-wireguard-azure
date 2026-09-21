# Spec Delta

## MODIFIED Requirements

### Requirement: Automated WireGuard server initialization
The virtual machine initialization SHALL configure Linux kernel IPv4 packet forwarding, install WireGuard and firewall tooling, generate server cryptographic key pairs, establish the `wg0` network interface, and configure NAT masquerading rules. During initialization of the first peer (`client1`), the system SHALL also generate a 256-bit pre-shared key using `wg genpsk`, store it at `/etc/wireguard/client1_psk.key` with `0600` permissions, and write it as `PresharedKey` in both the server's `[Peer]` block for `client1` and in `client1`'s `[Peer]` block pointing to the server.

#### Scenario: System startup and service readiness
- **WHEN** the virtual machine completes boot and cloud-init execution
- **THEN** IPv4 packet forwarding is enabled in the kernel, the `wg0` interface is configured and listening on UDP port 51820, and the `wg-quick@wg0` systemd service is active and enabled across reboots

#### Scenario: Initial peer has a pre-shared key
- **WHEN** the virtual machine completes cloud-init and the `wg0.conf` and `client1.conf` are generated
- **THEN** both files contain a matching `PresharedKey` line in their respective `[Peer]` blocks, and the PSK file exists at `/etc/wireguard/client1_psk.key` with permissions `0600`

### Requirement: Client configuration and peer connectivity
The system SHALL generate an initial client configuration containing private and public keys, assigned tunnel IP address, server public key, server public endpoint, and default routing rules, enabling connected clients to route outbound traffic through the VPN gateway. Every generated client configuration SHALL include a `PresharedKey` in its `[Peer]` block matching the server's corresponding `[Peer]` entry. No peer configuration SHALL be generated or activated without a PSK.

#### Scenario: Client tunnel connection and egress routing
- **WHEN** a client imports the generated client configuration and establishes a WireGuard tunnel
- **THEN** client network traffic directed through the tunnel is masqueraded by the server and egresses to the Internet bearing the Azure VM's public IP address

#### Scenario: All generated peer configurations include a PSK
- **WHEN** any client configuration is generated (initial or via `add-wg-client`)
- **THEN** the client `.conf` file contains a `PresharedKey` field in the `[Peer]` block, and the server's `wg0.conf` contains a matching `PresharedKey` field in the corresponding `[Peer]` block

#### Scenario: PSK file stored securely on server
- **WHEN** a peer's PSK is generated
- **THEN** it is stored at `/etc/wireguard/<client-name>_psk.key` with owner `root:root` and permissions `0600`; the PSK is not stored in any world-readable file or log
