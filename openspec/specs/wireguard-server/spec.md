# wireguard-server Specification

## Purpose

Provisions and manages an automated WireGuard VPN gateway on an Azure Linux virtual machine in a cost-effective European cloud region, providing secure and high-speed encrypted remote network access.

## Requirements

### Requirement: Deployable in low-cost European Azure region
The infrastructure configuration SHALL provision the virtual machine and supporting network resources in a configurable Azure region, defaulting to a cost-effective European location (such as `swedencentral`), utilizing burstable compute and standard storage resources to minimize hosting costs.

#### Scenario: Default European region deployment
- **WHEN** the user deploys the infrastructure without specifying a region override
- **THEN** the system provisions all resources in the `swedencentral` region using burstable B-series VM compute and standard disk storage

#### Scenario: Custom region override
- **WHEN** the user provides an alternative Azure region variable
- **THEN** the system successfully targets and provisions the resources in the specified region

### Requirement: Network security and port exposure
The network security group SHALL permit inbound UDP traffic on port 51820 from any source address for VPN tunnel traffic, and SHALL restrict SSH administrative access on port 22 to explicitly authorized CIDR ranges.

#### Scenario: WireGuard tunnel ingress permitted
- **WHEN** an external client transmits UDP datagrams targeting port 51820 of the public IP
- **THEN** the network security group allows the inbound packets through to the virtual machine network interface

#### Scenario: Unauthorized SSH access blocked
- **WHEN** an inbound TCP connection on port 22 originates from an IP address outside the configured authorized CIDR list
- **THEN** the network security group denies and drops the connection attempt

### Requirement: Automated WireGuard server initialization
The virtual machine initialization SHALL configure Linux kernel IPv4 packet forwarding, install WireGuard and firewall tooling, generate server cryptographic key pairs, establish the `wg0` network interface, and configure NAT masquerading rules.

#### Scenario: System startup and service readiness
- **WHEN** the virtual machine completes boot and cloud-init execution
- **THEN** IPv4 packet forwarding is enabled in the kernel, the `wg0` interface is configured and listening on UDP port 51820, and the `wg-quick@wg0` systemd service is active and enabled across reboots

### Requirement: Client configuration and peer connectivity
The system SHALL generate an initial client configuration containing private and public keys, assigned tunnel IP address, server public key, server public endpoint, and default routing rules, enabling connected clients to route outbound traffic through the VPN gateway. The DNS resolver address in generated client configurations SHALL be set to the WireGuard server's tunnel IP (`10.8.0.1`), which hosts Pi-hole; no public DNS resolver address SHALL appear in generated client configuration files.

#### Scenario: Client tunnel connection and egress routing
- **WHEN** a client imports the generated client configuration and establishes a WireGuard tunnel
- **THEN** client network traffic directed through the tunnel is masqueraded by the server and egresses to the Internet bearing the Azure VM's public IP address

#### Scenario: Client DNS resolver set to Pi-hole
- **WHEN** a client imports the generated client configuration
- **THEN** the `DNS` field in the `[Interface]` section is `10.8.0.1` and no public DNS resolver (e.g., `1.1.1.1`, `8.8.8.8`) is present

### Requirement: Outputting operational connection details
The infrastructure deployment SHALL provide outputs containing the server public IP address, listening port, SSH administrative connection command, and instructions for retrieving or viewing the generated client configuration.

#### Scenario: Inspecting deployment outputs
- **WHEN** the infrastructure provisioning process completes
- **THEN** the system outputs the public IP address, WireGuard listening port, administrative SSH access command, and retrieval commands for the client VPN profile
