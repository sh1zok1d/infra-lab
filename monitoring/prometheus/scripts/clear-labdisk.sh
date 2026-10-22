#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
docker compose run --rm -T disk-writer -c 'rm -f /labdisk/fill.bin && df -h /labdisk'
