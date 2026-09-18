# Tasks

## 1. Terraform Base Configuration and Variables

- [x] 1.1 Create `versions.tf` defining required Terraform core version (>= 1.5.0) and providers (`hashicorp/azurerm`, `hashicorp/cloudinit`, `hashicorp/random`), and verify with `terraform fmt -check`.
- [x] 1.2 Create `variables.tf` declaring configuration options (`location` defaulting to `swedencentral`, `vm_size` defaulting to `Standard_B1s`, `admin_username`, `ssh_public_key`, `wireguard_port`, and `admin_ssh_allowed_cidrs`), and verify types and descriptions.
- [x] 1.3 Create `terraform.tfvars.example` demonstrating default settings, EU region customization, and SSH IP restriction examples, verifying all declared variables are represented.

## 2. Cloud-Init Template for WireGuard Automation

- [x] 2.1 Author `templates/cloud-init.yaml.tftpl` configuring kernel IPv4 packet forwarding, package installations (`wireguard`, `iptables`, `qrencode`), server key generation, `wg0.conf` with NAT masquerading, initial client profile generation (`client1.conf`), and starting `wg-quick@wg0`, verifying YAML syntax.
- [x] 2.2 Include the `/usr/local/bin/add-wg-client` peer management script in the cloud-init template to support issuing extra client profiles, verifying script logic and execution permissions.

## 3. Azure Infrastructure Resources

- [x] 3.1 Create `main.tf` provisioning the dedicated Azure Resource Group, Virtual Network (`10.0.0.0/16`), and Subnet (`10.0.1.0/24`), verifying resource definitions.
- [x] 3.2 Add Static Standard Public IP, Network Interface (NIC), Network Security Group (NSG) with UDP 51820 and TCP 22 security rules, and NIC-NSG association, verifying network security binding.
- [x] 3.3 Add `azurerm_linux_virtual_machine` resource deploying Ubuntu 24.04 LTS, burstable B1s SKU, standard disk storage, SSH key authentication, and custom_data linked to the rendered cloud-init template, verifying configuration parameters.

## 4. Outputs and Operational Documentation

- [x] 4.1 Create `outputs.tf` exposing `server_public_ip`, `wireguard_port`, `ssh_connection_string`, and the command to display or retrieve the client configuration, verifying outputs format.
- [x] 4.2 Create a comprehensive root `README.md` with prerequisites, step-by-step deployment guide, client profile import instructions, and teardown commands, verifying documentation completeness.

## 5. Verification and Validation

- [x] 5.1 Run `terraform init` and `terraform validate` to verify the syntactical correctness and provider compatibility of all Terraform manifests.
- [x] 5.2 Run `openspec validate deploy-wireguard-azure-vm` to verify that the proposal, specs, design, and tasks strictly conform to OpenSpec schemas.
