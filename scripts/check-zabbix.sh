#!/usr/bin/env bash
# Read-only smoke-check for the local Zabbix project. Does not remove containers/data.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/monitoring/zabbix"
if docker info >/dev/null 2>&1; then
  docker_cmd=(docker)
else
  docker_cmd=(sudo docker)
fi
printf '%s\n' '[1] Compose configuration'
"${docker_cmd[@]}" compose config --quiet
printf '%s\n' '[2] Services'
"${docker_cmd[@]}" compose ps
printf '%s\n' '[3] Agent /labdisk'
"${docker_cmd[@]}" exec -T zabbix-agent df -h /labdisk
printf '%s\n' '[4] Docker DNS (resolver check only; Zabbix may differ)'
"${docker_cmd[@]}" exec -T zabbix-server getent hosts zabbix-agent || true
printf '%s\n' '[5] Web UI HTTP status'
if command -v curl >/dev/null; then
  curl --silent --output /dev/null --write-out 'HTTP %{http_code}\n' http://127.0.0.1:8080/ || true
else
  echo 'curl missing, skipped'
fi
printf '%s\n' 'Check Monitoring -> Latest data and Problems manually for end-to-end validation.'
