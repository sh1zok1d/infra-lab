#!/usr/bin/env bash
# Scenario 01. Symptom: "No space left on device" on /mnt/labdata, df says plenty free.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo"; exit 1; }

if [[ "${1:-}" == "--verify" ]]; then
  if touch /mnt/labdata/verify-$$ 2>/dev/null; then rm -f /mnt/labdata/verify-$$; echo "FIXED: writes work"; exit 0
  else echo "STILL BROKEN"; exit 1; fi
fi

mkdir -p /mnt/labdata/.cache/sessions
# fill inodes, not bytes
i=0; while touch "/mnt/labdata/.cache/sessions/s$i" 2>/dev/null; do i=$((i+1)); done
echo "broken. symptom: try   echo hi > /mnt/labdata/test.txt"
