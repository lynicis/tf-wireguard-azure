# Design

## Context

The goal is to provide a cost-effective, self-hosted WireGuard VPN gateway in Microsoft Azure using Terraform. See [proposal.md](proposal.md) for background motivation and high-level scope. 

The architecture consists of a single Azure Linux Virtual Machine operating as a WireGuard server, configured with automated kernel routing and firewall masquerading, situated inside a minimal Virtual Network (VNet) and protected by a Network Security Group (NSG).

## Goals / Non-Goals

**Goals:**
- Provide clean, reproducible Terraform infrastructure-as-code for Azure.
- Default to the most cost-effective European Azure region (e.g. `swedencentral`), with parameterization allowing other regions (`northeurope`, `polandcentral`, etc.).
- Default to low-cost burstable compute (`Standard_B1s`) and standard disk storage to keep operational costs below ~$5-7/month.
- Fully automate server provisioning, kernel packet forwarding, iptables NAT rules, and initial client profile generation via cloud-init.
- Secure administrative access (SSH) via configurable CIDR whitelisting and SSH key authentication.
- Output actionable operational details (public IP, WireGuard port, SSH access command, and retrieval instructions for the client configuration).

**Non-Goals:**
- Multi-region high availability, failover clusters, or auto-scaling VM scalesets (unnecessary complexity and cost for personal/small-team VPN).
- Deploying complex web GUI management dashboards (e.g. wg-easy / firezone) that require running Docker daemons and consume extra VM RAM/CPU.
- Azure Virtual Network Gateway (ExpressRoute / Azure VPN Gateway), which costs upwards of $25-$100+/month.

## Decisions

### 1. Default Azure Region: Sweden Central (`swedencentral`)
- **Choice**: Default `var.location` to `swedencentral`.
- **Rationale**: Sweden Central consistently offers among the lowest retail compute and egress pricing in Azure Europe, is powered by 100% carbon-free energy, and has wide availability of B-series burstable VMs.
- **Alternatives Considered**: 
  - `northeurope` (Ireland): Excellent availability and mature pricing, kept as an easy variable alternative.
  - `westeurope` (Netherlands): Slightly higher compute costs and tighter B-series quota availability.

### 2. VM SKU and Disk Sizing: `Standard_B1s` with Standard SSD
- **Choice**: `Standard_B1s` (1 vCPU, 1.0 GiB RAM) paired with a 30 GB `StandardSSD_LRS` OS disk.
- **Rationale**: WireGuard operates directly in kernel space with minimal memory (<50 MB) and CPU footprint. 1 GiB RAM ensures reliable OS updates and cloud-init execution without out-of-memory errors (which can occur on 512 MB `Standard_B1ls`). Standard SSD provides a cost-effective balance between disk latency and price (~$1.50/mo).
- **Alternatives Considered**:
  - `Standard_B1ls` (512 MB RAM): Cheaper by ~$1/mo, but prone to OOM hangs during `apt-get upgrade` or cloud-init execution.
  - `Standard_B2s` (2 vCPU, 4 GiB RAM): More headroom for higher throughput (>200 Mbps) or multi-peer setups; easily selectable via `var.vm_size`.

### 3. In-Kernel WireGuard & Cloud-Init Automation
- **Choice**: Provision Ubuntu 24.04 LTS using a `cloud-init` template (`templates/cloud-init.yaml.tftpl`) rendered via Terraform's `templatefile`.
- **Rationale**: Ubuntu 24.04 includes Linux kernel 6.8 with built-in WireGuard module support. Cloud-init executes natively at first boot without requiring external configuration managers (Ansible, Chef) or SSH bastion dependencies:
  - Writes `/etc/sysctl.d/99-wireguard.conf` (`net.ipv4.ip_forward = 1`).
  - Installs `wireguard`, `wireguard-tools`, `iptables`, and `qrencode`.
  - Generates cryptographic key pairs for both server and initial client (`client1`).
  - Creates `/etc/wireguard/wg0.conf` with PostUp / PostDown `iptables` NAT masquerade rules on the primary network interface (`eth0`).
  - Generates ready-to-use `/etc/wireguard/client1.conf` with server endpoint set to the VM's Public IP.
  - Enables and starts `wg-quick@wg0.service`.
  - Installs a helper CLI script `/usr/local/bin/add-wg-client` for issuing additional peer configurations on demand.
- **Alternatives Considered**:
  - Containerized WireGuard (Docker): Requires Docker engine installation (~300MB disk/memory overhead) and additional container management.
  - Terraform remote-exec provisioner: Fragile, requires SSH connection from Terraform runner, and fails if network firewalls block runner IP.

### 4. Network and Security Architecture
- **Choice**: Dedicated Resource Group with a VNet (`10.0.0.0/16`), a single Subnet (`10.0.1.0/24`), a Standard Static Public IP, and a Network Security Group (NSG).
- **Rules**:
  - `Allow-WireGuard-Inbound`: Protocol UDP, Port 51820, Source `*`, Priority 100.
  - `Allow-SSH-Inbound`: Protocol TCP, Port 22, Source `var.admin_ssh_allowed_cidrs` (defaults to `["0.0.0.0/0"]` with clear warning to restrict), Priority 110.
  - All other inbound traffic blocked by default Azure NSG rules.
- **Alternatives Considered**:
  - Dynamic Public IP (Basic SKU): Azure has deprecated Basic SKU Public IPs; Standard SKU with Static allocation prevents the WireGuard endpoint IP from shifting when the VM is stopped.

### 5. Terraform File Layout
- `versions.tf`: Provider requirements (`hashicorp/azurerm`, `hashicorp/cloudinit`, `hashicorp/random`).
- `variables.tf`: Inputs (`location`, `resource_group_name`, `vm_size`, `admin_username`, `ssh_public_key`, `wireguard_port`, `admin_ssh_allowed_cidrs`, etc.).
- `main.tf`: Core cloud resources (Resource Group, VNet, Subnet, Public IP, NSG, NIC, NIC-NSG association, Linux VM).
- `templates/cloud-init.yaml.tftpl`: Script and cloud-init template for WireGuard setup.
- `outputs.tf`: Outputs (`server_public_ip`, `wireguard_port`, `ssh_connection_string`, `get_client_config_command`).
- `terraform.tfvars.example`: Ready-to-copy example variable values.

## Risks / Trade-offs

- **[Risk] B-series CPU Credit Exhaustion under heavy traffic** → **Mitigation**: Standard B1s earns credits when idle; streaming high-bandwidth traffic continuously could deplete credits. Users can switch `var.vm_size` to `Standard_B2s` or `Standard_D2as_v5` with zero architecture changes.
- **[Risk] SSH Port 22 Brute-force Exposure** → **Mitigation**: Support `admin_ssh_allowed_cidrs` to restrict SSH ingress to the administrator's trusted public IP; enforce SSH key pair authentication only (password authentication disabled).
- **[Risk] Public IP Egress Costs in Azure** → **Mitigation**: First 100 GB/month of Internet egress is free across Azure accounts; beyond that, Azure bandwidth charges apply (~$0.08/GB in Europe). This is standard for any cloud-hosted VPN.
- **[Risk] Cloud-init execution lag** → **Mitigation**: WireGuard server packages and keys are created during first-boot cloud-init (typically completes within 60-90 seconds after VM creation). Document the status check command (`cloud-init status --wait`).

## Migration Plan

1. **Deploy**:
   - `terraform init`
   - `cp terraform.tfvars.example terraform.tfvars` and customize inputs (e.g. `ssh_public_key`, `admin_ssh_allowed_cidrs`).
   - `terraform apply`
2. **Access Client Config**:
   - Run the output SSH command or retrieve `/etc/wireguard/client1.conf` from the VM.
   - Import the configuration into the WireGuard desktop or mobile client.
3. **Teardown / Rollback**:
   - `terraform destroy` completely removes all Azure resources, stopping billing immediately.
