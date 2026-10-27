#!/usr/bin/env bash
# Scenario 04. Symptom: apt/curl/ping by name fail, ping 1.1.1.1 works.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo"; exit 1; }

if [[ "${1:-}" == "--verify" ]]; then
  if getent hosts deb.debian.org | grep -qv '^127\.' && getent hosts archive.ubuntu.com | grep -qv '^127\.'; then echo "FIXED"; exit 0
  else echo "STILL BROKEN"; exit 1; fi
fi

# two layers: resolved points at a dead resolver, and /etc/hosts has a poisoned entry
mkdir -p /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/lab.conf <<'EOF'
[Resolve]
DNS=10.255.255.1
FallbackDNS=
EOF
systemctl restart systemd-resolved
echo "127.0.0.2 archive.ubuntu.com security.ubuntu.com" >> /etc/hosts
echo "broken. symptom: curl -I https://deb.debian.org ; apt-get update ; ping 1.1.1.1"
