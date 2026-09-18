# Proposal

## Why

Deploying a private WireGuard VPN gateway on a low-cost virtual machine in an affordable European Azure region gives users a secure, dedicated, and high-performance tunnel for privacy and remote access without paying high managed VPN gateway costs. Utilizing Terraform ensures reproducible, parameterizable, and automated infrastructure as code for provisioning the network, compute, security, and VPN service.

## What Changes

- Create a modular Terraform configuration using the AzureRM provider to provision all necessary cloud resources:
  - Azure Resource Group.
  - Virtual Network and Subnet.
  - Public IP (Standard SKU) and Network Interface (NIC).
  - Network Security Group (NSG) with rules permitting WireGuard UDP traffic (default port 51820) and optional administrative SSH (port 22) restricted to authorized CIDRs.
  - Cost-effective Linux Virtual Machine (defaulting to `swedencentral` and `Standard_B1s` burstable SKU with Standard SSD/HDD storage).
- Automate WireGuard server installation and initialization via cloud-init / user-data:
  - Enable Linux kernel IPv4/IPv6 packet forwarding.
  - Install WireGuard tools and iptables.
  - Automatically configure `wg0` network interface with iptables NAT masquerading.
  - Generate server and initial client keypairs and wireguard configuration files.
  - Enable and start the `wg-quick@wg0` systemd service.
- Provide clear Terraform outputs and configuration variables for customizable regions, VM sizing, allowed CIDRs, and client connection details.

## Capabilities

### New Capabilities
- `wireguard-server`: Provisions the Azure compute and network infrastructure, configures the WireGuard VPN service via cloud-init, sets up firewall rules, and generates initial client connection credentials.

### Modified Capabilities
*(None)*

## Impact

- **Infrastructure**: Adds new Azure cloud infrastructure manageable entirely via Terraform (`main.tf`, `variables.tf`, `outputs.tf`, `cloud-init.yaml`).
- **Dependencies**: Requires Terraform >= 1.5.0, AzureRM Provider >= 3.0, and an active Azure subscription with sufficient quota in the chosen EU region (e.g., `swedencentral`).
- **Security**: Exposes UDP port 51820 to the internet for WireGuard tunnel traffic; restricts or flags SSH port 22 access to specified management CIDRs.
