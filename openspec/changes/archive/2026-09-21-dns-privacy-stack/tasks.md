# Tasks

## 1. Unbound Installation and Configuration

- [x] 1.1 In `cloud-init.yaml.tftpl`, add `unbound` and `unbound-anchor` to the `packages` list and verify the list compiles without YAML syntax errors
- [x] 1.2 Add a `write_files` entry that writes `/etc/unbound/unbound.conf.d/pi-hole.conf` with the configuration from design.md (interface `127.0.0.1`, port `5335`, verbosity `0`, no forwarder, `logfile: ""`, `log-queries: no`, `log-replies: no`) and verify the file content matches the design spec exactly
- [x] 1.3 Add a `runcmd` step (before the Pi-hole installer step) that downloads root hints via `curl -o /var/lib/unbound/root.hints https://www.internic.net/domain/named.root`, enables and starts `unbound`, and verify by running `systemctl is-active unbound` on the provisioned VM
- [x] 1.4 Verify no `forward-zone` entries exist in any Unbound config file on the VM after provisioning (`grep -r forward-zone /etc/unbound/` should return empty)

## 2. Pi-hole Installation and No-Log Configuration

- [x] 2.1 Add a `write_files` entry that writes `/etc/pihole/setupVars.conf` with the pre-seeded values from design.md (`PIHOLE_INTERFACE=10.8.0.1`, `QUERY_LOGGING=false`, `INSTALL_WEB_SERVER=false`, `INSTALL_WEB_INTERFACE=false`, `LIGHTTPD_ENABLED=false`, `PIHOLE_DNS_1=127.0.0.1#5335`, `PIHOLE_DNS_2=`) and verify the file is written before the installer runs
- [x] 2.2 Add a `write_files` entry that writes `/etc/pihole/pihole-FTL.conf` with `PRIVACYLEVEL=3` and `DBFILE=` (empty, disables the query database) and verify the file exists with correct content after provisioning
- [x] 2.3 Add a `runcmd` step (after Unbound is running) that downloads and runs the Pi-hole installer in unattended mode (`curl -sSL https://install.pi-hole.net | bash /dev/stdin --unattended`) and verify `pihole status` reports DNS as active on the provisioned VM
- [x] 2.4 Add a `runcmd` step to restart `pihole-FTL` after the installer so the no-log `pihole-FTL.conf` overrides take effect, and verify `pihole -q <any-domain>` does not produce query log entries in `/var/log/pihole/pihole.log`

## 3. DNS Field Update in WireGuard Client Configs

- [x] 3.1 In `templates/cloud-init.yaml.tftpl`, in the `init-wireguard.sh` heredoc that writes `client1.conf`, change `DNS = 1.1.1.1, 1.0.0.1` to `DNS = 10.8.0.1` and verify the generated `/etc/wireguard/client1.conf` contains exactly `DNS = 10.8.0.1` after provisioning
- [x] 3.2 In `templates/cloud-init.yaml.tftpl`, in the `add-wg-client` heredoc that writes client configs, change `DNS = 1.1.1.1, 1.0.0.1` to `DNS = 10.8.0.1` and verify a new client added via `sudo add-wg-client testclient` produces a `.conf` file with `DNS = 10.8.0.1`

## 4. Pi-hole Listen Interface Enforcement

- [x] 4.1 Confirm that after provisioning, Pi-hole's `PIHOLE_INTERFACE` binding causes `pihole-FTL` to listen only on `10.8.0.1:53` and not on the public NIC; verify with `ss -ulnp | grep 53` — the public IP should not appear on port 53
- [x] 4.2 Confirm the existing NSG has no inbound rule allowing port 53 from internet sources; verify in Terraform state or Azure portal that the only inbound rules remain WireGuard UDP 51820 and SSH TCP 22

## 5. End-to-End DNS Validation

- [x] 5.1 Connect a VPN client using the updated `client1.conf` and run `dig google.com @10.8.0.1` from the client — verify a valid DNS response is returned, confirming Pi-hole is reachable via the tunnel and Unbound resolves recursively
- [x] 5.2 On the VM, run `dig pi-hole.net @127.0.0.1 -p 5335` — verify a valid DNS answer is returned directly from Unbound, confirming recursive resolution from root servers works
- [x] 5.3 On the VM, check that no query log entries appear after running several DNS lookups: `cat /var/log/pihole/pihole.log` should not contain per-query records; `journalctl -u unbound --no-pager | grep query` should return empty
