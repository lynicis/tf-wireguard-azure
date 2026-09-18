# WireGuard VPN on Microsoft Azure

A production-ready, cost-optimized, automated WireGuard VPN gateway deployed on Microsoft Azure using Terraform.

By default, this configuration deploys to **Sweden Central (`swedencentral`)**—one of Azure's most cost-effective, 100% renewable-powered European cloud regions—on a burstable `Standard_B1s` virtual machine running **Ubuntu 24.04 LTS**. Total operational cost is approximately **$5–$7 / month**.

---

## Architecture Overview

```
[ Client Device ]
       │  (WireGuard Tunnel: UDP 51820)
       ▼
[ Azure Public IP (Standard SKU, Static) ]
       │
[ Azure Network Security Group (NSG) ]
  ├── UDP 51820 : Allowed (All)
  └── TCP 22    : Allowed (Configurable Admin CIDRs)
       │
[ Virtual Network (10.0.0.0/16) / Subnet (10.0.1.0/24) ]
       │
[ Linux VM: Standard_B1s (Ubuntu 24.04 LTS) ]
  ├── In-kernel WireGuard (wg0: 10.8.0.1/24)
  ├── iptables NAT Masquerade (eth0 egress)
  └── Sysctl IPv4/IPv6 packet forwarding
       │
       ▼ (Egress with VM Public IP)
   [ Internet ]
```

---

## Prerequisites

Before starting, ensure you have:

1. **Terraform** >= 1.5.0 installed ([Download Terraform](https://developer.hashicorp.com/terraform/install)).
2. **Azure CLI** (`az`) installed and authenticated:
   ```bash
   az login
   az account set --subscription "<your-subscription-id-or-name>"
   ```
3. An **SSH Key Pair** (e.g. `~/.ssh/id_ed25519.pub` or `~/.ssh/id_rsa.pub`):
   ```bash
   # Generate if you do not already have one:
   ssh-keygen -t ed25519 -C "admin@wireguard-azure"
   ```
4. A **WireGuard Client** installed on your client devices ([wireguard.com/install](https://www.wireguard.com/install/)).

---

## Step-by-Step Deployment Guide

### 1. Clone & Prepare Variables

Copy the example variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

- Set `ssh_public_key` to your public SSH key string (e.g., `cat ~/.ssh/id_ed25519.pub`).
- Set `admin_ssh_allowed_cidrs` to restrict administrative SSH access to your public IP (e.g. `["203.0.113.50/32"]`).
- (Optional) Adjust `location`, `vm_size`, or `wireguard_port` as desired.

### 2. Initialize and Deploy

```bash
# Initialize Terraform and download providers
terraform init

# Review execution plan
terraform plan

# Deploy infrastructure
terraform apply
```

Deployment of cloud resources takes approximately 1 to 2 minutes.

### 3. Server Initialization (Cloud-Init)

Once Azure finishes creating the VM, the system executes first-boot automation (`cloud-init`) to install packages, configure kernel packet forwarding, set up iptables NAT masquerading, and generate keypairs.

This usually takes **60 to 90 seconds**. You can check the boot progress:

```bash
# Connect to the server
$(terraform output -raw ssh_connection_string)

# Wait for cloud-init to complete
cloud-init status --wait
```

---

## Connecting to the VPN

An initial client profile (`client1.conf`) is automatically created during server boot.

### Option A: Mobile Setup (QR Code)

To connect an iOS or Android device, simply display the ANSI QR code in your terminal:

```bash
$(terraform output -raw get_qr_code_command)
```

Open the **WireGuard app** on your phone, tap **+** -> **Create from QR code**, scan the terminal code, and activate!

### Option B: Desktop Setup (macOS / Windows / Linux)

Download the generated configuration file to your computer using `scp`:

```bash
SERVER_IP=$(terraform output -raw server_public_ip)
scp azureuser@$SERVER_IP:~/wireguard-clients/client1.conf ./client1.conf
```

Open the WireGuard desktop application, click **Add Tunnel** -> Select `client1.conf`, and click **Activate**.

### Option C: View Configuration in Terminal

```bash
$(terraform output -raw get_client_config_command)
```

---

## Adding Additional Client Peers

You can issue additional client configurations at any time using the bundled management script `/usr/local/bin/add-wg-client`:

```bash
# SSH into the server
$(terraform output -raw ssh_connection_string)

# Generate a profile for a new client (e.g., "laptop" or "phone")
sudo add-wg-client laptop
```

This helper script will:
1. Dynamically allocate the next available IP address in the `10.8.0.0/24` subnet.
2. Generate private/public cryptographic keys.
3. Hot-add the peer to the running `wg0` interface without downtime.
4. Save the configuration to `~/wireguard-clients/<client-name>.conf`.
5. Display a terminal QR code for instant scanning.

---

## Verification & Troubleshooting

- **Check WireGuard Status on Server**:
  ```bash
  sudo wg show
  ```
- **Check System Service**:
  ```bash
  sudo systemctl status wg-quick@wg0
  ```
- **Inspect Cloud-Init Logs**:
  ```bash
  cat /var/log/cloud-init-output.log
  ```
- **Verify Public IP on Client**:
  Once connected to the VPN on your client device, verify your outgoing IP address matches the Azure VM:
  ```bash
  curl ifconfig.me
  ```

---

## Teardown / Destruction

To destroy all cloud resources and stop billing immediately:

```bash
terraform destroy -auto-approve
```
