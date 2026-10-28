# Infra Lab — Day 2: Prometheus, Alertmanager and Grafana

This self-contained Docker Compose lab demonstrates metrics scraping, PromQL,
stateful alert rules, Alertmanager routing, a real webhook receiver, and
file-provisioned Grafana dashboards. It is intended as a **portfolio exercise**.

## Architecture and scope

```text
node-exporter:9100 --> Prometheus:9090 --> Alertmanager:9093 --> alert-echo:8080
                         ^
                         |
                    Grafana:3000
```

Five long-running containers; all Web UIs are bound to **127.0.0.1**.
The `disk-writer` service is disabled by default (Compose profile `tools`)
and is used only for short-lived one-shot commands.

**Metrics scope:** Node exporter reads Linux kernel CPU/memory counters from
its container, and filesystem metrics from mounts visible inside that container.
The 64 MiB `/labdisk` volume is NOT a host mount, and these stats should
not be misrepresented as full host monitoring. `/labdisk` uses a shared Docker
volume backed by tmpfs. Only the test volume is filled.

## Setup (run on the Docker host)

```bash
cd ~/infra-lab/monitoring/prometheus
printf 'GF_SECURITY_ADMIN_PASSWORD=%s\n' "$(openssl rand -hex 16)" > .env
chmod 600 .env
sudo docker compose config --quiet
sudo docker compose up -d
sudo docker compose ps
```

Grafana login: `admin`, password from `cat .env` (do not commit it).

- Prometheus targets: http://127.0.0.1:9090/targets
- Prometheus alerts: http://127.0.0.1:9090/alerts
- Alertmanager: http://127.0.0.1:9093
- Grafana: http://127.0.0.1:3000
- Echo receiver (JSON endpoint): http://127.0.0.1:8081/alerts/alerts

First verify `prometheus` and `node` are both **UP**, then run:

```promql
up
node_filesystem_size_bytes{job="node", mountpoint="/labdisk"}
100 * (1 - node_filesystem_avail_bytes{job="node",mountpoint="/labdisk"} / node_filesystem_size_bytes{job="node",mountpoint="/labdisk"})
node_memory_MemAvailable_bytes{job="node"} / node_memory_MemTotal_bytes{job="node"}
rate(node_cpu_seconds_total{job="node",mode="idle"}[5m])
100 - avg by(instance)(rate(node_cpu_seconds_total{job="node",mode="idle"}[5m])) * 100
```

`rate()` converts a monotonically increasing counter to a per-second rate;
`[5m]` is the time window used for the calculation. `instance` and `job` are labels.

## Failure simulation and recovery

The node-exporter official image is minimal and generally has no `sh`/`dd`.
**Do not** use `docker exec node-exporter sh ...`.

Run from the Docker host in this directory:

```bash
sudo docker compose run --rm -T disk-writer -c 'dd if=/dev/zero of=/labdisk/fill.bin bs=1M count=54 && df -h /labdisk'
```

This uses a temporary BusyBox container sharing the same 64 MiB tmpfs volume.
Watch `LabDiskAlmostFull` at http://127.0.0.1:9090/alerts:

1. Metric crosses 80%; after a rule evaluation the alert becomes **Pending**.
2. After continuously true for `30s`, the alert becomes **Firing**.
3. Alertmanager groups it, waits `group_wait: 10s`, then POSTs to `alert-echo`.
4. `sudo docker compose logs --tail=80 alert-echo` and http://127.0.0.1:8081/alerts
   show the actual JSON payload (`status=firing`).

Resolve:

```bash
sudo docker compose run --rm -T disk-writer -c 'rm -f /labdisk/fill.bin && df -h /labdisk'
```

Look for a `status=resolved` payload. Exact delays depend on the scrape /
evaluation timing and Alertmanager grouping, and should be measured rather
than assumed. The receiver keeps the latest 100 events in memory only.

## Alertmanager inhibition

`TargetDown` (critical) is configured to inhibit warning-level alerts with
the same `instance`. Stopping the exporter will typically make disk metrics
stale/absent and cause their alerts to resolve before `TargetDown` fires.
**Do not claim this proves inhibition**; an explicit overlapping synthetic
alert test is needed for that. You can still test `TargetDown` by running:

```bash
sudo docker compose stop node-exporter
# Observe `up{job="node"}` -> 0 and TargetDown pending/firing.
sudo docker compose start node-exporter
```

## Grafana as code

`grafana/provisioning/datasources/prometheus.yml` provisions the datasource.
`grafana/provisioning/dashboards/providers.yml` declares a file provider,
loading JSON dashboards from `grafana/dashboards/`.
The included `infra-lab-overview.json` appears on first startup.

Optionally import community dashboard **1860** from the Grafana UI (internet
may be required). Export its JSON into `grafana/dashboards/node-exporter-full.json`.
Grafana periodically scans the directory, so restart is usually unnecessary.

See the [verified Day 2 report](../../docs/day2-prometheus.md) and the [synthetic inhibition test](../../scenarios/06-alertmanager-inhibition.md). The Grafana dashboard was verified to remain available after a Grafana restart.

## What to capture for GitHub

- Screenshots: Targets UP, PromQL results, Pending + Firing, Alertmanager,
  Echo `firing` and `resolved`, Grafana dashboard.
- `docs/day2-prometheus.md`: exact observed times, rule explanation, outcome,
  comparison with Zabbix, and limitations.
- Never commit the real `.env`, tokens or auth cookies.

## Cleanup

```bash
sudo docker compose down
```

Do **not** run `down -v` if you want to retain time-series data and Grafana state.
