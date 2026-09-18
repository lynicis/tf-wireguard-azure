variable "admin_ssh_allowed_cidrs" {
  description = "List of IPv4/IPv6 CIDR blocks permitted to access administrative SSH (port 22). Restrict to your trusted IP ranges."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "admin_username" {
  description = "Administrator username for the Linux virtual machine."
  type        = string
  default     = "azureuser"
}

variable "location" {
  description = "The Azure region where all resources will be provisioned. Defaults to cost-effective Sweden Central."
  type        = string
  default     = "swedencentral"
}

variable "resource_group_name" {
  description = "Name of the Azure Resource Group."
  type        = string
  default     = "rg-wireguard-vpn"
}

variable "ssh_public_key" {
  description = "SSH public key content (e.g. ~/.ssh/id_rsa.pub or ~/.ssh/id_ed25519.pub) for authenticating as admin_username."
  type        = string
}

variable "vm_size" {
  description = "Azure Virtual Machine SKU size. Defaults to economical burstable Standard_B1s."
  type        = string
  default     = "Standard_B1s"
}

variable "wireguard_port" {
  description = "UDP port for incoming WireGuard tunnel traffic."
  type        = number
  default     = 51820
}
