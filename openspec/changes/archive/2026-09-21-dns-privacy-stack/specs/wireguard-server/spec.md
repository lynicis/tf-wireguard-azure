# Spec Delta

## MODIFIED Requirements

### Requirement: Client configuration and peer connectivity
The system SHALL generate an initial client configuration containing private and public keys, assigned tunnel IP address, server public key, server public endpoint, and default routing rules, enabling connected clients to route outbound traffic through the VPN gateway. The DNS resolver address in generated client configurations SHALL be set to the WireGuard server's tunnel IP (`10.8.0.1`), which hosts Pi-hole; no public DNS resolver address SHALL appear in generated client configuration files.

#### Scenario: Client tunnel connection and egress routing
- **WHEN** a client imports the generated client configuration and establishes a WireGuard tunnel
- **THEN** client network traffic directed through the tunnel is masqueraded by the server and egresses to the Internet bearing the Azure VM's public IP address

#### Scenario: Client DNS resolver set to Pi-hole
- **WHEN** a client imports the generated client configuration
- **THEN** the `DNS` field in the `[Interface]` section is `10.8.0.1` and no public DNS resolver (e.g., `1.1.1.1`, `8.8.8.8`) is present
