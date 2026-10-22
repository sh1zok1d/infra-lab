#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# The exporter image contains no shell, so a one-shot BusyBox container fills
# the exact same 64 MiB Docker volume. No Kali host disk is filled.
docker compose run --rm -T disk-writer -c   'dd if=/dev/zero of=/labdisk/fill.bin bs=1M count=54 && df -h /labdisk'
