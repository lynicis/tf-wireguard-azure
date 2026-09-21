# Proposal

## Why

VPN clients currently use Cloudflare's public DNS (`1.1.1.1`, `1.0.0.1`), leaking DNS query metadata to a third-party resolver and gaining no ad-blocking benefit. Adding Pi-hole (DNS sinkhole) and Unbound (recursive resolver) on the same VM eliminates the external DNS dependency, blocks ads and trackers at the network level, and enforces a no-log policy end-to-end — ensuring that no query metadata persists on the server or is sent upstream.

## What Changes

- Install **Pi-hole** on the WireGuard VM via cloud-init, configured to listen on the WireGuard tunnel interface (`10.8.0.1`) only
- Install **Unbound** as Pi-hole's upstream recursive resolver, resolving DNS directly from root servers without forwarding to any third-party
- Configure Pi-hole's DNS upstream to point exclusively at Unbound (`127.0.0.1#5335`)
- Configure **no-log policies** across both services:
  - Pi-hole: query logging disabled, no FTL database writes
  - Unbound: log verbosity 0, `logfile: ""`, no query log
- Update WireGuard client configuration template: DNS field changed from `1.1.1.1, 1.0.0.1` to `10.8.0.1` (Pi-hole on the server)
- Update `add-wg-client` script to reflect the new DNS value in generated client configs
- Add NSG rule to allow DNS (UDP/TCP port 53) from WireGuard tunnel subnet (`10.8.0.0/24`) to the VM — **intra-host traffic only, not exposed publicly**

## Capabilities

### New Capabilities

- `dns-privacy-stack`: Private, recursive DNS with ad-blocking — Pi-hole and Unbound installed on the WireGuard VM, receiving queries from VPN clients and resolving them locally with no logging and no third-party DNS dependency

### Modified Capabilities

- `wireguard-server`: DNS field in generated client configurations changes from public resolvers to the WireGuard server's tunnel IP (`10.8.0.1`); the no-log policy requirement is added to the server's operational contract

## Impact

- `templates/cloud-init.yaml.tftpl`: installs `pi-hole`, `unbound`; adds configuration files for both services; updates DNS values in `init-wireguard.sh` and `add-wg-client`
- `main.tf`: may add an NSG rule scoped to the WireGuard subnet for DNS traffic (not public-facing)
- Client `.conf` files already generated on existing deployments will continue working but will need manual DNS update or re-provisioning to use Pi-hole
- No new Terraform variables required; Pi-hole's web admin password can be randomized and output or set to a fixed value (assumption: disabled web UI or admin password output via Terraform)
