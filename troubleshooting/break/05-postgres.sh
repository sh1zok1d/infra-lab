#!/usr/bin/env bash
# Scenario 05. Symptom: labdb-check fails; postgres "active (running)".
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo"; exit 1; }

PGCONF=$(ls /etc/postgresql/*/main/postgresql.conf | head -1)
PGHBA=$(dirname "$PGCONF")/pg_hba.conf

if [[ "${1:-}" == "--verify" ]]; then
  if labdb-check | grep -q "20[0-9][0-9]-"; then echo "FIXED"; exit 0
  else echo "STILL BROKEN: $(labdb-check)"; exit 1; fi
fi

cp -n "$PGCONF" "$PGCONF.lab-backup" || true
cp -n "$PGHBA" "$PGHBA.lab-backup" || true
# layer 1: listen only on unix socket
sed -i "s/^#\?listen_addresses.*/listen_addresses = ''/" "$PGCONF"
# layer 2: even if you fix that, hba now rejects the app role from localhost
sed -i "/^host.*all.*all.*127.0.0.1\/32/i host    labdb    labapp    127.0.0.1/32    reject" "$PGHBA"
systemctl restart postgresql
echo "broken. symptom: labdb-check ; systemctl status postgresql"
