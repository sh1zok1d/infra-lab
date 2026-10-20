# Infra Lab — Zabbix monitoring

A small, reproducible Linux monitoring lab using **Zabbix 7.0 LTS**, Docker Compose and PostgreSQL. The first exercise covers a custom disk-usage metric, threshold alerting, low-level discovery and incident recovery.

## Architecture

```text
Browser (127.0.0.1:8080) -> Zabbix Web
                                  |
                             PostgreSQL
                                  |
Zabbix Server -> Zabbix Agent 2 (lab-host)
                      |
                /labdisk (64 MiB tmpfs)
```

All services run in Docker. The agent observes **its container**, not the underlying Linux host.

## Quick start

Requires Linux, Docker Engine and Docker Compose v2.

```bash
cd monitoring/zabbix
printf 'ZBX_DB_PASSWORD=%s\n' "$(openssl rand -hex 24)" > .env
chmod 600 .env
docker compose config --quiet
docker compose up -d
docker compose ps
```

Open <http://127.0.0.1:8080> (initial credentials: `Admin` / `zabbix`; change the password). In **Data collection → Hosts**, create `lab-host`, use the `Linux by Zabbix agent` template and an Agent interface with **DNS** `zabbix-agent`, port `10050`.

For the custom check, create a Zabbix-agent item with key `vfs.fs.size[/labdisk,pused]`, type `Numeric (float)`, update interval `30s`, and a High-severity trigger:

```text
last(/lab-host/vfs.fs.size[/labdisk,pused])>80
```

Template exports and setup notes: [monitoring/zabbix](monitoring/zabbix/README.md).

## Tested

- Agent availability and metric collection in **Latest data**.
- Custom disk usage item and High-severity trigger; disk-full problem and automatic recovery (**30 seconds observed**).
- Filesystem LLD; automatically generated items and reviewed item/trigger prototypes.
- Telegram notification delivery.
- Troubleshooting of the agent restart loop and container DNS resolution.

## Incidents

- [Disk-full alert and recovery](scenarios/01-disk-full.md)
- [Agent restart loop](scenarios/02-agent-crash-loop.md)
- [DNS resolution during agent restart](scenarios/03-dns-resolution.md)

[Day 1 report and screenshots](docs/day1-zabbix.md)

## Security

The Web UI binds only to `127.0.0.1:8080`; server/agent ports are not published on the host. `.env` and credentials are excluded from Git. Telegram integration and the host's custom monitoring objects were configured through the UI, so a fresh Compose launch requires the manual steps above.

**Next:** Prometheus/Grafana and Ansible.
