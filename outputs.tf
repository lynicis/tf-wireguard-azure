# ==============================================================================
# WireGuard Deployment Outputs
# ==============================================================================

output "get_client_config_command" {
  description = "Command to retrieve and print the client1 WireGuard profile directly to stdout."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.wireguard.ip_address} \"cat /home/${var.admin_username}/wireguard-clients/client1.conf\""
}

output "get_qr_code_command" {
  description = "Command to print the client1 QR code in the terminal for instant mobile setup."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.wireguard.ip_address} \"qrencode -t ansiutf8 < /home/${var.admin_username}/wireguard-clients/client1.conf\""
}

output "server_public_ip" {
  description = "The public IPv4 address assigned to the WireGuard VPN gateway."
  value       = azurerm_public_ip.wireguard.ip_address
}

output "ssh_connection_string" {
  description = "SSH command to connect to the WireGuard server for administration."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.wireguard.ip_address}"
}

output "wireguard_port" {
  description = "The UDP port on which WireGuard listens."
  value       = var.wireguard_port
}
