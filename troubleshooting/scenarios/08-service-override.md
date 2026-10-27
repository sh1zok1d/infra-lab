# 08 — Service restart loop after a bad drop-in override

Date: 2026-10-27 · Time to resolve: ~8 min · Detected by: drill (break/02-service.sh)

## Symptom
curl http://127.0.0.1:8085/ fails. systemctl status labapp: activating (auto-restart),
Process: ... ExecStart=/usr/bin/python3.99 ... (code=exited, status=203/EXEC).
Status also shows Drop-In: /etc/systemd/system/labapp.service.d/override.conf.

## Investigation
1. systemctl status labapp — not running, restarting in a loop; exit status 203/EXEC means
   systemd could not execute the binary at all (missing file or no permission).
2. journalctl -u labapp -n 30 — empty: run as a regular user. sudo journalctl -u labapp -n 30 —
   Unable to locate executable '/usr/bin/python3.99': No such file or directory, restart counter at 78.
3. systemctl cat labapp — prints the unit and the drop-in on top of it. The override changed two things:
   ExecStart to a non-existent interpreter python3.99, and Environment=LABAPP_PORT=eighty-eighty-five.

## Root cause
A drop-in override (labapp.service.d/override.conf) replaced ExecStart with a path that does not exist.
The second change (non-numeric port) was also wrong but never reached: the process died before the
application read its environment. Two independent faults; only the first one was visible.

## Fix
sudo systemctl revert labapp — removes all drop-ins and restores the unit as installed.
Then sudo systemctl daemon-reload && sudo systemctl restart labapp → active (running), curl returns labapp OK.
(rm -r labapp.service.d would have the same effect; revert is the safer, intended command.)

Observation: break/02-service.sh --verify still reported STILL BROKEN while the service was healthy.
The verify script used curl -f, and the demo server resets the connection right after sending the
response (curl: (56) Connection reset by peer); curl treats that as a failure. The verification tool was
wrong, not the service — confirmed by systemctl status and the actual HTTP response.

## Prevention / detection
- Keep systemd overrides in git and deploy them with Ansible, not by hand on the host; a wrong path is
  visible in the diff before it reaches production.
- Alert on restart loops: node_exporter --collector.systemd exposes node_systemd_unit_state;
  alert when a unit is not active for more than a minute.
- Test systemctl daemon-reload && systemctl restart immediately after editing a unit, and read
  systemctl status — don't walk away after the edit.

## Lessons
- status=203/EXEC = the binary could not be executed; check the path in ExecStart first.
- journalctl -u for system services needs sudo (or membership in adm / systemd-journal).
- systemctl cat shows the effective unit including drop-ins — the fastest way to see what an override changed.
- An empty ExecStart= line in a drop-in is intentional: it clears the list before setting a new value.
- Verify the verifier: a failing check with a healthy service means the check is wrong.
