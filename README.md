# Infra Lab — Linux Monitoring & Incident Response

A hands-on, growing infrastructure portfolio built on local **Kali Linux + Docker Compose**. The focus is not just launching containers: each lab includes monitored signals, an intentionally induced failure, troubleshooting, recovery, and a documented verification trail.

## Labs at a glance

| Lab | Stack | Verified outcome | Report |
| --- | --- | --- | --- |
| Day 1 | Zabbix 7.0 LTS, Agent 2, PostgreSQL | Custom disk item / High trigger, filesystem LLD, synthetic disk incident with 30-second **event duration** | [Zabbix report](docs/day1-zabbix.md) |
| Day 2 | Prometheus 3.6.0, node_exporter, Alertmanager, Grafana | PromQL, disk alert Pending → Firing → Resolved, real webhook deliveries, exporter outage, inhibition, file-provisioned dashboard | [Prometheus report](docs/day2-prometheus.md) |

**Scope:** The Zabbix agent observes its container. The Prometheus exporter exposes Linux CPU/memory kernel counters and container-visible mounts. Both disk-full experiments use a dedicated **64 MiB tmpfs**; neither is a destructive test of the Kali root disk.

## Architecture

```text
Day 1 (127.0.0.1:8080)
  Browser -> Zabbix Web -> PostgreSQL
                   |
              Zabbix Server -> Zabbix Agent 2 -> /labdisk

Day 2 (127.0.0.1:9090 / :9093 / :3000 / :8081)
  node_exporter -> Prometheus ----> Alertmanager ---> alert-echo
                       ^
                       |
                     Grafana
```

Separate Docker Compose projects and named volumes. Web ports bind to localhost; secret `.env` files are excluded from source control.

## Getting started

Requirements: Linux, Docker Engine, Docker Compose v2.

**Zabbix**

```bash
cd monitoring/zabbix
printf 'ZBX_DB_PASSWORD=%s\n' "$(openssl rand -hex 24)" > .env
chmod 600 .env
docker compose config --quiet
docker compose up -d
```

Open <http://127.0.0.1:8080>. The host, agent item and trigger were configured through the UI during Day 1; see [Zabbix setup](monitoring/zabbix/README.md) and [known portability limitations](docs/day1-zabbix.md#limitations--work-remaining).

**Prometheus, Alertmanager and Grafana**

```bash
cd monitoring/prometheus
printf 'GF_SECURITY_ADMIN_PASSWORD=%s\n' "$(openssl rand -hex 16)" > .env
chmod 600 .env
docker compose config --quiet
docker compose up -d
docker compose ps
```

Prometheus [Targets](http://127.0.0.1:9090/targets) / [Alerts](http://127.0.0.1:9090/alerts) · [Alertmanager](http://127.0.0.1:9093) · [Grafana](http://127.0.0.1:3000) · [Webhook events](http://127.0.0.1:8081/alerts)

Grafana username: `admin`; password from your local `monitoring/prometheus/.env`. The dashboard and datasource load from files. See the [Prometheus runbook](monitoring/prometheus/README.md) for reproduction and safe cleanup.

## Incident runbooks

| # | Scenario | What it demonstrates |
| --- | --- | --- |
| 01 | [Zabbix disk-full and recovery](scenarios/01-disk-full.md) | Agent item + trigger |
| 02 | [Zabbix agent restart loop](scenarios/02-agent-crash-loop.md) | Log-guided configuration debugging |
| 03 | [Zabbix agent DNS problem](scenarios/03-dns-resolution.md) | Network troubleshooting, unresolved application-level DNS detail |
| 04 | [Prometheus disk-full and recovery](scenarios/04-prometheus-disk-full.md) | Metrics, Pending/Firing, real firing/resolved webhooks |
| 05 | [node_exporter down](scenarios/05-node-exporter-down.md) | Target health / critical alert |
| 06 | [Alertmanager inhibition](scenarios/06-alertmanager-inhibition.md) | Suppressing secondary notifications using matching labels |
| 07 | [Inode exhaustion](troubleshooting/scenarios/07-inode-exhaustion.md) | "No space left" with free bytes; df -i, find by directory |
| 08 | [Service restart loop](troubleshooting/scenarios/08-service-override.md) | 203/EXEC, systemctl cat, drop-in overrides, revert |
| 09 | [Port conflict](troubleshooting/scenarios/09-port-conflict.md) | ss -tlnp, identifying an unmanaged process, when kill is safe |
| 10 | [DNS resolution](troubleshooting/scenarios/10-dns-resolution.md) | resolved drop-ins, /etc/hosts precedence, verify the verifier |
Actual Day 2 webhook timestamps: [JSON evidence extract](docs/evidence/day2-webhook-evidence.json).

## Zabbix vs Prometheus — observed in these labs

| Dimension | Zabbix | Prometheus stack |
| --- | --- | --- |
| Collection in these exercises | Passive checks from Zabbix Agent 2 | HTTP polling of node_exporter |
| Storage | PostgreSQL | Built-in Prometheus TSDB |
| Detection logic | Item + trigger expression | PromQL rule, with `for` delay |
| Notification workflow | Actions and media types; **Telegram not tested here** | Alertmanager webhook; firing **and** resolved verified |
| Configuration as code | Export/import needed for UI-created objects; portability not fully validated | Native YAML rules, Compose files and Grafana JSON |
| Best fit (general) | Traditional host/network infrastructure, SNMP | Labeled time series, containers and cloud-native systems |

The Day 1 value **30 seconds** was the *recorded problem duration*, **not measured detection latency**. Day 2 included Pending/Firing and webhook timestamps, but did not isolate exact end-to-end detection latency. Do not compare these as if they were equivalent response times.

## Evidence, honesty and next steps

- [Day 1 screenshots](docs/day1-zabbix.md#evidence) document the Zabbix incident and filesystem LLD.
- [Day 2 report](docs/day2-prometheus.md) records tested states, commands, UTC timestamps and the inhibition API response. Screenshots from the local interactive session have **not yet been added** to this repository.
- Remaining portability work: Zabbix agent DNS resolution, Zabbix export/import verification, more representative host metrics, and repeatable smoke tests.
- Planned expansions: infrastructure automation (Ansible), service stack operations, backups and repeatable failure/recovery scenarios.

**Security:** Keep all real `.env` files, tokens and private keys out of Git. Do not expose local observability UIs directly to the internet.
