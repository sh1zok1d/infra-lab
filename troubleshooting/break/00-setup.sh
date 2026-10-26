#!/usr/bin/env bash
# One-time VM preparation for the troubleshooting scenarios. Safe to re-run.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo"; exit 1; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q nginx postgresql prometheus-node-exporter stress-ng curl jq openssl

# --- demo web app: static site + a tiny systemd service ---------------------
mkdir -p /var/www/lab
cat > /var/www/lab/index.html <<'EOF'
<h1>lab site OK</h1>
EOF
cat > /etc/nginx/sites-available/lab <<'EOF'
server {
    listen 80 default_server;
    root /var/www/lab;
    index index.html;
}
EOF
ln -sf /etc/nginx/sites-available/lab /etc/nginx/sites-enabled/lab
rm -f /etc/nginx/sites-enabled/default

# self-signed cert for the TLS scenario
mkdir -p /etc/nginx/tls
if [[ ! -f /etc/nginx/tls/lab.crt ]]; then
  openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
    -subj "/CN=lab.local" \
    -keyout /etc/nginx/tls/lab.key -out /etc/nginx/tls/lab.crt 2>/dev/null
fi
cat > /etc/nginx/sites-available/lab-tls <<'EOF'
server {
    listen 443 ssl;
    server_name lab.local;
    ssl_certificate     /etc/nginx/tls/lab.crt;
    ssl_certificate_key /etc/nginx/tls/lab.key;
    root /var/www/lab;
}
EOF
ln -sf /etc/nginx/sites-available/lab-tls /etc/nginx/sites-enabled/lab-tls
nginx -t && systemctl enable --now nginx && systemctl reload nginx

# --- "labapp": a python service that talks to postgres ----------------------
id -u labapp &>/dev/null || useradd -r -s /usr/sbin/nologin labapp
mkdir -p /opt/labapp /var/log/labapp
chown labapp:labapp /var/log/labapp
cat > /opt/labapp/app.py <<'EOF'
#!/usr/bin/env python3
import os, time, socket, sys
PORT = int(os.environ.get("LABAPP_PORT", "8085"))
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("0.0.0.0", PORT)); s.listen(5)
print(f"labapp listening on {PORT}", flush=True)
while True:
    c, _ = s.accept()
    c.sendall(b"HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\n\r\nlabapp OK\n"); c.close()
EOF
chmod +x /opt/labapp/app.py
cat > /etc/systemd/system/labapp.service <<'EOF'
[Unit]
Description=Lab demo application
After=network.target

[Service]
User=labapp
Environment=LABAPP_PORT=8085
ExecStart=/usr/bin/python3 /opt/labapp/app.py
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now labapp

# --- postgres: a database and role the app "uses" ---------------------------
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='labapp'" | grep -q 1 \
  || sudo -u postgres psql -c "CREATE ROLE labapp LOGIN PASSWORD 'labapp';"
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='labdb'" | grep -q 1 \
  || sudo -u postgres psql -c "CREATE DATABASE labdb OWNER labapp;"
cat > /usr/local/bin/labdb-check <<'EOF'
#!/usr/bin/env bash
PGPASSWORD=labapp psql -h 127.0.0.1 -U labapp -d labdb -tc "select now()" 2>&1
EOF
chmod +x /usr/local/bin/labdb-check

# --- nightly cron job that writes a report ----------------------------------
cat > /usr/local/bin/nightly-report <<'EOF'
#!/usr/bin/env bash
set -e
OUT=/var/log/labapp/nightly.log
echo "$(date -Is) report: $(df -h / | tail -1 | awk '{print $5}') used, $(uptime -p)" >> "$OUT"
EOF
chmod +x /usr/local/bin/nightly-report
cat > /etc/cron.d/nightly-report <<'EOF'
*/2 * * * * root /usr/local/bin/nightly-report
EOF
# (every 2 minutes in the lab so you don't wait for midnight)

# --- lab disk for the disk scenarios -----------------------------------------
if ! mountpoint -q /mnt/labdata; then
  mkdir -p /mnt/labdata
  fallocate -l 200M /var/lab-disk.img
  mkfs.ext4 -q -N 128 /var/lab-disk.img   # deliberately few inodes
  echo "/var/lab-disk.img /mnt/labdata ext4 loop 0 0" >> /etc/fstab
  mount /mnt/labdata
fi

systemctl enable --now prometheus-node-exporter

echo
echo "=== setup complete ==="
echo "nginx:      curl -s http://127.0.0.1/      -> $(curl -s http://127.0.0.1/ | head -c 30)"
echo "nginx tls:  curl -sk https://127.0.0.1/   -> $(curl -sk https://127.0.0.1/ | head -c 30)"
echo "labapp:     curl -s http://127.0.0.1:8085/ -> $(curl -s http://127.0.0.1:8085/)"
echo "postgres:   labdb-check               -> $(labdb-check | tr -d ' ')"
echo "labdata:    $(df -h /mnt/labdata | tail -1)"
echo "node_exp:   $(curl -s http://127.0.0.1:9100/metrics | grep -c '^node_' ) node_* metrics"
