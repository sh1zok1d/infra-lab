#!/usr/bin/env bash
# Scenario 02. Symptom: labapp.service keeps restarting, curl :8085 fails.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo"; exit 1; }

if [[ "${1:-}" == "--verify" ]]; then
  if systemctl is-active -q labapp && { curl -s http://127.0.0.1:8085/ 2>/dev/null || true; } | grep -q "labapp OK"; then echo "FIXED"; exit 0
  else echo "STILL BROKEN"; exit 1; fi
fi

# a "colleague" deployed a new version with a typo in the unit's env and
# a wrong path for the interpreter override
mkdir -p /etc/systemd/system/labapp.service.d
cat > /etc/systemd/system/labapp.service.d/override.conf <<'EOF'
[Service]
Environment=LABAPP_PORT=eighty-eighty-five
ExecStart=
ExecStart=/usr/bin/python3.99 /opt/labapp/app.py
EOF
systemctl daemon-reload
systemctl restart labapp || true
echo "broken. symptom: systemctl status labapp ; curl http://127.0.0.1:8085/"
