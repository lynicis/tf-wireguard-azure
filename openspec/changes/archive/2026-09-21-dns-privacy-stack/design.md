# Design

## Context

The project provisions a WireGuard VPN server on Azure (Ubuntu 24.04 LTS) using Terraform + cloud-init. All VM configuration — package installation, key generation, service setup — is done inside `templates/cloud-init.yaml.tftpl`. There is no configuration management tooling (Ansible, Chef, etc.); everything is provisioned at first boot.

Currently, generated client `.conf` files point DNS at `1.1.1.1, 1.0.0.1`. See `proposal.md – Why` for motivation.

## Goals / Non-Goals

**Goals:**
- Install Pi-hole and Unbound on the existing VM via cloud-init at provision time
- Route all VPN client DNS traffic through Pi-hole → Unbound (recursive, no forwarder)
- Enforce no-log policy: zero query persistence in Pi-hole FTL or Unbound logs
- Replace public DNS entries in all generated client configs with `10.8.0.1`
- Keep Pi-hole's DNS port off the public internet (NSG unchanged for port 53 externally)

**Non-Goals:**
- Pi-hole web admin UI exposure or access from VPN clients (UI can remain disabled or localhost-only)
- Custom block-list management beyond Pi-hole's default shipped lists
- IPv6 DNS support
- Support for existing deployed VMs (re-provisioning required; no in-place upgrade path in scope)

## Decisions

### D1: Pi-hole installed via official installer script (pihole-install.sh) with pre-seeded answers

**Decision**: Use Pi-hole's `basic-install.sh` with a pre-seeded `setupVars.conf` and environment variables to achieve a non-interactive installation in cloud-init.

**Why**: Pi-hole does not ship an Ubuntu APT package. Its official supported installation path is the installer script. Alternatives considered:
- *Docker*: Adds Docker runtime overhead; not present on the VM; requires extra cloud-init complexity.
- *Third-party apt repo*: Unofficial, not maintained by Pi-hole project; reliability risk.
- *pihole-FTL only*: Does not include the gravity/blocklist pipeline that makes Pi-hole useful.

**Configuration pre-seeded** via `/etc/pihole/setupVars.conf` before running installer:
```
PIHOLE_INTERFACE=10.8.0.1     # WireGuard tunnel IP — listen only on this
IPV4_ADDRESS=10.8.0.1/24
QUERY_LOGGING=false
INSTALL_WEB_SERVER=false
INSTALL_WEB_INTERFACE=false
LIGHTTPD_ENABLED=false
BLOCKING_ENABLED=true
PIHOLE_DNS_1=127.0.0.1#5335  # Unbound
PIHOLE_DNS_2=                 # No second upstream
```

Privacy level is set to `3` (`PRIVACYLEVEL=3`) in `pihole-FTL.conf` to suppress query logging.

### D2: Unbound configured to listen on 127.0.0.1:5335 only

**Decision**: Unbound listens on loopback port 5335 (not 53) to avoid conflicting with `systemd-resolved` or any future local DNS.

**Why**: Port 53 on loopback may be held by `systemd-resolved` (Ubuntu 24.04 default). Using 5335 is the conventional Pi-hole + Unbound port to avoid conflicts. Pi-hole's upstream is configured as `127.0.0.1#5335`.

**Unbound config** written to `/etc/unbound/unbound.conf.d/pi-hole.conf`:
```conf
server:
  verbosity: 0
  interface: 127.0.0.1
  port: 5335
  do-ip4: yes
  do-udp: yes
  do-tcp: yes
  do-ip6: no
  prefer-ip6: no
  root-hints: /var/lib/unbound/root.hints
  harden-glue: yes
  harden-dnssec-stripped: yes
  use-caps-for-id: no
  edns-buffer-size: 1232
  prefetch: yes
  num-threads: 1
  so-rcvbuf: 1m
  private-address: 192.168.0.0/16
  private-address: 169.254.0.0/16
  private-address: 172.16.0.0/12
  private-address: 10.0.0.0/8
  private-address: fd00::/8
  private-address: fe80::/10
  logfile: ""
  log-queries: no
  log-replies: no
```

Root hints downloaded at provision time via `curl` from `https://www.internic.net/domain/named.root`.

### D3: cloud-init ordering — Unbound before Pi-hole

**Decision**: Unbound is installed and started before Pi-hole runs its installer, so Pi-hole can immediately verify connectivity to its upstream on port 5335.

**Why**: Pi-hole's installer pings its configured DNS upstream. If Unbound is not running at installer time, the install may warn or fail validation.

**cloud-init sequence in `runcmd`**:
1. Install packages: `unbound`, `unbound-anchor`, `curl`
2. Write Unbound config and root hints
3. Enable and start `unbound`
4. Run Pi-hole installer (non-interactive)
5. Apply `pihole-FTL.conf` no-log overrides
6. Restart `pihole-FTL`
7. Run `init-wireguard.sh` (already present; DNS value updated in template)

### D4: No new Terraform variable for Pi-hole admin password

**Decision**: Pi-hole web UI is disabled entirely (`INSTALL_WEB_INTERFACE=false`); no admin password is needed or generated.

**Why**: The admin UI is not required — the VM is managed via SSH. Disabling the web interface removes the attack surface, avoids the need for a Terraform variable/output for the password, and is consistent with the no-log / minimal-footprint principle.

### D5: NSG — no new inbound rule for port 53

**Decision**: Do not add an NSG rule allowing inbound port 53 from the public internet. Pi-hole listens only on `10.8.0.1` (the WireGuard tunnel interface). DNS traffic from VPN clients reaches `10.8.0.1` via the WireGuard tunnel (UDP 51820, already permitted), not through a public DNS port.

**Why**: Exposing port 53 publicly would make the server an open DNS resolver, creating an amplification attack vector. VPN clients already have a path to `10.8.0.1` through the encrypted tunnel.

## Risks / Trade-offs

- **Pi-hole installer script fetches from internet at provision time** → Mitigation: cloud-init runs after network is up; if the CDN is unreachable, provisioning fails and the VM must be re-created. Risk is low (Pi-hole CDN is stable).
- **Root hints become stale** → Mitigation: Unbound's `prefetch` setting and DNSSEC keep responses fresh; root hints rarely change. Acceptable for a single-VM setup.
- **Existing deployed VMs are not updated** → Mitigation: Documented as out of scope. Re-provision to get the new stack. Existing client configs keep working with public DNS until the peer is re-added against a new VM.
- **Pi-hole installer is interactive by default** → Mitigation: `setupVars.conf` pre-seeding + `--unattended` flag suppress prompts. Tested path for cloud-init usage.
- **systemd-resolved conflict on port 53** → Mitigation: Unbound uses port 5335; Pi-hole is told to use `127.0.0.1#5335` as upstream. `systemd-resolved` remains untouched to avoid breaking other system DNS during provisioning.

## Migration Plan

This change applies only to newly provisioned VMs. No in-place migration is defined.

1. Update `cloud-init.yaml.tftpl` and optionally `main.tf`
2. Run `terraform destroy && terraform apply` (or recreate the VM) to provision a new instance with Pi-hole + Unbound
3. Re-distribute new client configs (DNS now points to `10.8.0.1`)
4. Existing clients using old configs continue to work via public DNS until updated
