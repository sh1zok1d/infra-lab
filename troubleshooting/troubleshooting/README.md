# Linux troubleshooting scenarios

Blind incident drills on a disposable Ubuntu VM. Each `break/NN-*.sh` script
breaks something; the matching `scenarios/NN-*.md` is written AFTER the fix.

## Rules

1. Run the script with `sudo`. Do not read it first.
2. Diagnose from symptoms only: logs, `systemctl`, `ss`, `df`, `journalctl`, `dmesg`.
3. Fix it. Then run `sudo bash break/NN-*.sh --verify` to confirm.
4. Write the runbook: symptom → how I found it → root cause → fix → how to prevent / detect earlier.
5. Only then read the script.

## Target VM

Fresh Ubuntu 24.04 (VM, LXC or cloud instance), 1 vCPU / 1 GB is enough.
Prepare it once with `sudo bash break/00-setup.sh`: installs nginx, PostgreSQL,
node_exporter, a small systemd service and a cron job that the scenarios use.
Point your Prometheus at this VM's node_exporter so some incidents show up as alerts first.

## Scenarios

| # | Area | Symptom you will see |
|---|------|----------------------|
| 01 | disk | writes fail, `df` looks fine |
| 02 | systemd | service exits immediately after start |
| 03 | network | web service down, nginx "running" |
| 04 | dns | hostnames stop resolving on the box |
| 05 | postgres | app cannot connect to the database |
| 06 | tls | nginx HTTPS refuses connections after reload |
| 07 | cron | nightly job silently stopped producing output |
| 08 | memory | random process gets killed every few minutes |
| 09 | permissions | nginx serves 403 for a site that worked yesterday |
| 10 | process | one process pins the CPU, box is sluggish |

Runbooks live in `scenarios/`. Screenshots and timestamps are evidence, not the write-up.
