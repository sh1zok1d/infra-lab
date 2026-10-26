#!/usr/bin/env bash
# Scenario 03. Symptom: http://host/ returns the wrong thing or nothing; nginx says active.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo"; exit 1; }

if [[ "${1:-}" == "--verify" ]]; then
  if curl -s http://127.0.0.1/ | grep -q "lab site OK" && ! pgrep -f rogue-listener >/dev/null; then echo "FIXED"; exit 0
  else echo "STILL BROKEN"; exit 1; fi
fi

systemctl stop nginx
# something else grabs :80 first, pretends to be a web server
cat > /usr/local/bin/rogue-listener <<'EOF'
#!/usr/bin/env python3
import socket
s=socket.socket(); s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
s.bind(("0.0.0.0",80)); s.listen(5)
while True:
    c,_=s.accept(); c.sendall(b"HTTP/1.0 503 Service Unavailable\r\n\r\nmaintenance\n"); c.close()
EOF
chmod +x /usr/local/bin/rogue-listener
nohup /usr/local/bin/rogue-listener >/dev/null 2>&1 &
sleep 1
systemctl start nginx || true
echo "broken. symptom: curl -i http://127.0.0.1/ ; systemctl status nginx"
