# Infrastructure & Observability Lab

A hands-on Linux infrastructure portfolio that grows through reproducible monitoring, network troubleshooting, failure simulations, and automation.

**Goal:** demonstrate practical Linux / Infrastructure / Network Operations engineering, not just installation screenshots.

## Progress

| Component | Status | Evidence |
| --- | --- | --- |
| Zabbix 7.0 LTS with PostgreSQL and Agent 2 | Done (local Kali) | [Day 1 report](docs/day1-zabbix.md) |
| Custom disk-usage item and high-severity trigger | Tested manually | [Disk-full incident](scenarios/01-disk-full.md) |
| Filesystem low-level discovery (LLD) | Inspected and observed | [Day 1 report](docs/day1-zabbix.md) |
| Telegram delivery | Skipped by choice; **not tested** | [Day 1 report](docs/day1-zabbix.md) |
| Prometheus, Grafana and Alertmanager | Planned | [Monitoring roadmap](monitoring/prometheus/README.md) |
| Ansible | Planned | [Ansible roadmap](ansible/README.md) |
| Application infrastructure and backups | Planned | [Stack roadmap](stack/README.md) |

## Architecture (Day 1)

```text
  Local browser http://127.0.0.1:8080
                  |
              Zabbix Web
                  |
       +----------+----------+
       |                     |
  PostgreSQL <------> Zabbix Server
                             |
                    Docker internal network
                             |
                       Zabbix Agent 2
                             |
                      /labdisk (64 MiB tmpfs)
```

The agent observes its own container, **not the Kali host**. Future work adds host-level monitoring.

## Quick start (fresh deployment)

Requires Linux, Docker Engine and Docker Compose v2. The Zabbix database password must stay out of Git.

```bash
cd monitoring/zabbix
printf 'ZBX_DB_PASSWORD=%s\n' "$(openssl rand -hex 24)" > .env
chmod 600 .env
docker compose config --quiet
docker compose up -d
docker compose ps
```

Open <http://127.0.0.1:8080>; initial credentials are `Admin` / `zabbix` — **change the password immediately**.

To reproduce the monitoring configuration, see the [Zabbix README](monitoring/zabbix/README.md). The PostgreSQL volume persists across normal `docker compose down`; **do not use `down -v`** on the existing lab.

**Existing Kali installation:** follow the [migration guide](docs/adopt-existing-lab.md) rather than creating a fresh `.env` or launching a duplicate Compose project.

## Troubleshooting stories

- [01 — Disk capacity threshold and recovery](scenarios/01-disk-full.md)
- [02 — Agent crash loop from duplicate server address](scenarios/02-agent-crash-loop.md)
- [03 — Container DNS resolution mismatch](scenarios/03-dns-resolution.md)

## Repository structure

```text
monitoring/zabbix/       Tested infrastructure and original/derived template files
monitoring/prometheus/  Reserved for the next monitoring stack
ansible/                Planned provisioning and configuration management
stack/                  Planned sample application infrastructure
scenarios/              Failure/recovery runbooks
scripts/                Local preflight checks
.github/workflows/       Static configuration validation on pushes and PRs
docs/                   Lab reports, migration notes, evidence
```

## Security and validation

- Web UI binds to `127.0.0.1:8080` only; Zabbix server and agent ports are not published externally.
- `.env` is ignored; only `.env.example` is committed.
- Do not commit tokens, local database volumes, machine-specific addresses or backup dumps.
- `bash scripts/check-zabbix.sh` checks the running local deployment without intentionally causing an incident.
- GitHub Actions checks Compose parsing and exported YAML structure; it does **not** deploy Zabbix or test the custom template import.

## Next engineering tasks

Resolve Zabbix async DNS lookup (currently temporarily works via container IP), fix the default `Zabbix server` host, and validate a fresh import of the derived monitoring template. These remain open, rather than being presented as production-ready.
