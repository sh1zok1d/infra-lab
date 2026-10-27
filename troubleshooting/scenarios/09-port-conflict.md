# 09 — nginx fails to start: port 80 taken by a rogue process

Date: 2026-10-27 · Time to resolve: ~7 min · Detected by: drill (break/03-port.sh)

## Symptom
curl -i http://127.0.0.1/ returns 503 Service Unavailable / maintenance instead of the site.
systemctl status nginx: failed (Result: exit-code), ExecStart ... status=1/FAILURE.

## Investigation
1. sudo journalctl -xeu nginx — nginx: [emerg] bind() to 0.0.0.0:80 failed (98: Address already in use),
   repeated five times, then still could not bind(). nginx itself is fine; the port is taken.
2. sudo ss -tlnp | grep :80 — 0.0.0.0:80 ... users:(("python3",pid=5809)). Not nginx.
   Note: grep :80 also matched :8085; use grep ':80 ' or ss -tlnp 'sport = :80'.
3. ps -o pid,ppid,user,lstart,cmd -p 5809 — PPID 1, user root, started 14:33:49,
   python3 /usr/local/bin/rogue-listener. Parent is PID 1: the process was orphaned (its shell exited).
4. sudo ls -l /proc/5809/cwd — started from a user's home directory, not from a system path.
5. systemctl status 5809 — belongs to session-1.scope (an interactive login session), not to any
   service unit. Nobody manages it; it will not survive a reboot.

## Root cause
A process started by hand (nohup ... & from a login shell) bound 0.0.0.0:80 before nginx started.
nginx could not bind the port and exited. The rogue process answered HTTP with 503, so the port
looked "open" from outside while the real service was down.

## Fix
sudo kill 5809 → ss -tlnp shows :80 free → sudo systemctl start nginx →
curl -i http://127.0.0.1/ returns HTTP/1.1 200 OK, Server: nginx, site content.
Killing was safe because the process had no unit, no documented owner, and was orphaned.

## Prevention / detection
- Before killing a listener on prod: systemctl status <pid> (unit or not), ps (who/when),
  /proc/<pid>/cwd and /proc/<pid>/exe (where from), journalctl _COMM=sudo (who started it).
  No unit, no owner, no docs → kill. Otherwise ask first.
- Anything that must own a privileged port runs as a systemd unit, not from a shell.
- Monitoring: node_systemd_unit_state{name="nginx.service"} catches the failed unit, but only an
  HTTP probe (blackbox_exporter http_2xx on /) catches "port open, wrong service answering".
  Port checks test the listener; content checks test the service.

## Lessons
- bind() ... (98: Address already in use) → ss -tlnp first, not nginx config.
- systemctl status <pid> tells you whether a process is managed by a unit or by nobody.
- PPID 1 on a non-service process means it was orphaned — started interactively, parent gone.
- Running a bash script with sh/dash breaks on bashisms like $EUID; use the interpreter in the shebang.
