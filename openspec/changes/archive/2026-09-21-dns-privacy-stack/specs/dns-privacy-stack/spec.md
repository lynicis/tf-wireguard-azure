# Spec Delta

## Purpose

Provides a self-hosted, privacy-preserving DNS resolution layer on the WireGuard VM — Pi-hole handles ad/tracker blocking and DNS-over-WireGuard for connected clients, while Unbound performs recursive resolution directly against root DNS servers, with no query logging enabled in either service.

## ADDED Requirements

### Requirement: Pi-hole receives DNS queries from VPN clients
Pi-hole SHALL listen for DNS queries exclusively on the WireGuard tunnel interface address (`10.8.0.1`) on port 53, so that only clients connected to the VPN tunnel can send DNS requests to it. Pi-hole SHALL NOT be accessible on the VM's public-facing network interface.

#### Scenario: VPN client DNS query resolved via Pi-hole
- **WHEN** a VPN-connected client sends a DNS query to `10.8.0.1`
- **THEN** Pi-hole receives and processes the query, returning a response (either a blocked NXDOMAIN/null-route for sinkholed domains, or a resolved answer via Unbound)

#### Scenario: Public DNS port not exposed
- **WHEN** an external host attempts a DNS query on UDP/TCP port 53 to the VM's public IP
- **THEN** the network security group drops the traffic and the query does not reach Pi-hole

### Requirement: Unbound resolves DNS recursively with no upstream forwarder
Unbound SHALL act as Pi-hole's exclusive upstream resolver, listening on `127.0.0.1` port `5335`, and SHALL resolve DNS queries by iterating from root name servers directly without forwarding to any third-party resolver (no 1.1.1.1, 8.8.8.8, or equivalent).

#### Scenario: Unbound resolves a query recursively
- **WHEN** Pi-hole forwards a non-blocked DNS query to `127.0.0.1#5335`
- **THEN** Unbound resolves it by querying authoritative name servers from the root down and returns the answer to Pi-hole

#### Scenario: No third-party upstream configured
- **WHEN** Unbound is inspected for its configuration
- **THEN** no external forwarder addresses are present in its configuration; `forward-zone` entries SHALL NOT exist

### Requirement: No-log policy enforced on Pi-hole and Unbound
Both Pi-hole and Unbound SHALL operate with query logging disabled. Pi-hole SHALL NOT write query logs to its FTL database. Unbound SHALL NOT write query logs to any file or system log. No DNS query metadata SHALL be persisted on the server.

#### Scenario: Pi-hole query logging disabled
- **WHEN** Pi-hole is running and processing DNS queries
- **THEN** no query records are written to the FTL database (`/etc/pihole/pihole-FTL.db` remains empty of query data or is not created for queries); Pi-hole's `privacylevel` is set to `3` (no logging)

#### Scenario: Unbound produces no query log output
- **WHEN** Unbound is running and resolving queries
- **THEN** no query-level log entries are written to any file or forwarded to syslog; log verbosity is set to `0`

### Requirement: VPN client configurations reference Pi-hole as DNS resolver
All generated WireGuard client configuration files SHALL set their DNS field to `10.8.0.1` (the Pi-hole address on the WireGuard tunnel). No public DNS resolver addresses SHALL appear in generated client configurations.

#### Scenario: Initial client config DNS points to Pi-hole
- **WHEN** the VM completes cloud-init and the initial client configuration is generated
- **THEN** the client's `[Interface]` section contains `DNS = 10.8.0.1` and no other DNS addresses

#### Scenario: Dynamically added client config DNS points to Pi-hole
- **WHEN** the `add-wg-client` script creates a new client configuration
- **THEN** the resulting `.conf` file contains `DNS = 10.8.0.1` and no other DNS addresses
