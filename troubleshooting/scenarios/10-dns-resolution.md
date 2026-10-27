# 10 — Name resolution broken: wrong global DNS plus a poisoned /etc/hosts

Date: 2026-10-27 · Time to resolve: ~10 min · Detected by: drill (break/04-dns.sh)

## Symptom
curl -I https://deb.debian.org and apt-get update fail on name lookup; ping 1.1.1.1 works.
Network is up; turning names into addresses is what fails.

## Investigation
1. resolvectl status — Global: DNS Servers: 10.255.255.1; Link 2 (enp0s3): DNS Servers: 10.0.2.3.
   ip a confirms enp0s3 is the only interface. 10.0.2.3 is what VirtualBox NAT hands out via DHCP;
   10.255.255.1 was handed out by nobody — it must come from a file.
2. cat /etc/systemd/resolved.conf — everything commented out. ls /etc/systemd/resolved.conf.d/ — lab.conf
   with DNS=10.255.255.1 and FallbackDNS= (empty, so no fallback). A drop-in overriding the main config,
   same mechanism as a systemd unit override.
3. After fixing DNS, --verify said FIXED, but cat /etc/hosts showed
   127.0.0.2 archive.ubuntu.com security.ubuntu.com. /etc/hosts is consulted before DNS, so those two
   names resolved to the local machine; apt would have talked to the lab nginx instead of the Ubuntu mirror.
   The verify script only checked that getent returned *something* — it did, just the wrong thing.

## Root cause
Two independent faults. (1) A manually added resolved drop-in pointed the global resolver at an unreachable
address and disabled fallback, so every lookup timed out. (2) A poisoned /etc/hosts entry redirected two
mirror hostnames to 127.0.0.2, invisible to a "did it resolve" check.

## Fix
1. sudo rm /etc/systemd/resolved.conf.d/lab.conf && sudo systemctl restart systemd-resolved —
   global DNS gone, resolved falls back to the per-link server from DHCP. getent hosts deb.debian.org returns real addresses.
2. Removed the 127.0.0.2 line from /etc/hosts. getent hosts archive.ubuntu.com now returns public addresses.
Deleting the drop-in was correct because DHCP-provided DNS works and nothing documented the manual server.
If the manual server were the company's internal resolver, the fix would be on the server side, not deleting the config.

## Prevention / detection
- Resolver config and /etc/hosts are managed by Ansible; a diff from git = alert, not a surprise during an incident.
- blackbox_exporter dns module: resolve a known name through the local resolver every minute and compare
  the answer, not just the presence of one.
- When a lookup fails, split the question: can the host *ask* (resolvectl, resolv.conf, drop-ins, firewall on UDP/53)
  vs does the server *answer correctly* (dig @10.0.2.3 name vs dig @1.1.1.1 name).

## Lessons
- "Resolving" = turning a name into an address. IP works, name fails → resolution, not network.
- Order of lookup: /etc/hosts first, then DNS. A hosts entry silently wins.
- Config directories ending in .d hold overrides; check them before the main file.
- A check that passes while the system is wrong is a bug in the check (second time this week).
