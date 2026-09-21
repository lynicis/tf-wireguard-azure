# Tasks

## 1. PSK Generation in init-wireguard.sh (client1 at boot)

- [x] 1.1 In `templates/cloud-init.yaml.tftpl`, inside the `init-wireguard.sh` heredoc, after the `client1` private/public key generation block, add a `wg genpsk` call that writes the result to `/etc/wireguard/client1_psk.key` with `umask 077` and `chmod 600`; verify the file exists with correct permissions after provisioning (`ls -la /etc/wireguard/client1_psk.key` shows `-rw------- root root`)
- [x] 1.2 In the same heredoc, capture the PSK into a variable (`CLIENT1_PSK=$(cat "$WG_DIR/client1_psk.key")`) and add `PresharedKey = $CLIENT1_PSK` to the server-side `[Peer]` block for `client1` in `wg0.conf`; verify `cat /etc/wireguard/wg0.conf` shows a `PresharedKey` line under the client1 peer section
- [x] 1.3 Add `PresharedKey = $CLIENT1_PSK` to the `[Peer]` block in the generated `client1.conf` (the block pointing to the server); verify `cat /etc/wireguard/client1.conf` contains `PresharedKey` in the `[Peer]` section and the value matches the server's entry

## 2. PSK Generation in add-wg-client (runtime peers)

- [x] 2.1 In `templates/cloud-init.yaml.tftpl`, inside the `add-wg-client` heredoc, after the client private/public key generation block, add `wg genpsk` to produce and store `/etc/wireguard/<CLIENT_NAME>_psk.key` with `umask 077` and `chmod 600`, owner `root:root`; verify a newly added client has its PSK file at the correct path with correct permissions
- [x] 2.2 Extend the `wg set wg0 peer "$CLIENT_PUB_KEY" allowed-ips "$CLIENT_IP/32"` call in `add-wg-client` to include `preshared-key <(cat "$WG_DIR/${CLIENT_NAME}_psk.key")` using process substitution so the PSK is applied to the live WireGuard interface without the key appearing in process arguments; verify `sudo wg show wg0` lists `preshared key: (hidden)` for the new peer
- [x] 2.3 Append `PresharedKey = $CLIENT_PSK` to the new peer's `[Peer]` block in `wg0.conf` (the persistent config); verify `grep -A5 "# Peer: $CLIENT_NAME" /etc/wireguard/wg0.conf` shows a `PresharedKey` line
- [x] 2.4 Add `PresharedKey = $CLIENT_PSK` to the `[Peer]` block in the generated client `.conf` file written to `$CLIENTS_DIR`; verify the output config file contains the correct `PresharedKey` value and it matches the server-side entry

## 3. Security Verification

- [ ] 3.1 On the provisioned VM, run `sudo wg show wg0` and confirm all listed peers show `preshared key: (hidden)` — verify no peer is listed without a PSK entry
- [ ] 3.2 Verify PSK files are not world-readable: `find /etc/wireguard -name '*_psk.key' -perm /o+r` should return empty; confirm each file is `0600` owned by `root`
- [ ] 3.3 Confirm no PSK value appears in any system log: `journalctl -b | grep -i preshared` should return no lines containing key material (WireGuard never logs key values, but verify the cloud-init runcmd output does not echo the variable)

## 4. End-to-End Connectivity Validation

- [ ] 4.1 Import the updated `client1.conf` (containing `PresharedKey`) into a WireGuard client and establish a tunnel; verify a successful handshake is shown in `sudo wg show wg0` (latest handshake timestamp updates) and internet traffic routes through the VPN
- [ ] 4.2 Run `sudo add-wg-client testpeer` on the VM, import the generated config, connect, and verify a handshake completes — confirming end-to-end PSK negotiation works for dynamically added peers
