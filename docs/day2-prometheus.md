# Day 2 — Prometheus, Alertmanager and Grafana

**Date:** 2026-10-22  
**Status:** Hands-on lab completed; observed outcomes documented below  
**Environment:** Local Kali Linux, Docker Compose; Prometheus 3.6.0, node_exporter 1.9.1, Alertmanager 0.28.1, Grafana 12.1.1, Python 3.12 alert receiver.

## Objective

Deploy a file-configured metrics and alerting stack; use PromQL to inspect Linux metrics; reproduce disk saturation and exporter outages; confirm webhook delivery and recovery; validate Alertmanager inhibition and Grafana dashboard provisioning.

## Architecture

```text
node_exporter (:9100, lab-host)
      |
      | HTTP scrape (15s)
      v
Prometheus (:9090; TSDB + rules every 15s)
      |                          ^
      | notifications            | PromQL queries
      v                          |
Alertmanager (:9093)         Grafana (:3000)
      |
      | HTTP POST /alerts
      v
alert-echo (:8081 on localhost)
```

Five long-running Docker services. A separate, one-shot `disk-writer` (BusyBox) writes only to a shared **64 MiB tmpfs** volume exposed to node_exporter as `/labdisk`. All published HTTP ports bind to `127.0.0.1`.

Source: [Compose file](../monitoring/prometheus/docker-compose.yml), [Prometheus configuration](../monitoring/prometheus/prometheus/prometheus.yml), [alert rules](../monitoring/prometheus/prometheus/rules/node.yml), [Alertmanager configuration](../monitoring/prometheus/alertmanager/alertmanager.yml).

## Verified results

| Test | Observation | Result |
| --- | --- | --- |
| Containers | Prometheus, node_exporter, Alertmanager, Grafana, alert-echo running | PASS |
| Targets / PromQL | `prometheus` and `node` UP; `up` returned 1 for both | PASS |
| Memory | ~61% available in a live query | PASS |
| CPU | Six logical CPU series; ~22.82% average CPU busy from a 5-minute `rate()` window | PASS |
| Test filesystem | `node_filesystem_size_bytes{mountpoint="/labdisk"} = 67108864` (64 MiB); initially 0% used | PASS |
| Disk alert | Wrote 54 MiB; **84.375%** observed; `LabDiskAlmostFull` transitioned **Pending → Firing** | PASS |
| Alertmanager delivery | `LabDiskAlmostFull` shown in Alertmanager; webhook received `status: firing` | PASS |
| Recovery | Removed test file; all five Prometheus rules shown Inactive; webhook received `status: resolved` | PASS |
| Exporter outage | Stopped node_exporter; target DOWN, `TargetDown` reached Firing (critical); service restarted | PASS |
| Inhibition | Injected synthetic critical `TargetDown` and warning `DemoWarning` for the same instance directly into Alertmanager; API reported `active` and `suppressed` | PASS |
| Dashboard as code | Provisioned Grafana dashboard displayed five panels and **survived Grafana restart** | PASS |

## PromQL learned

```promql
up
node_filesystem_size_bytes{mountpoint="/labdisk"}
100 * (1 - node_filesystem_avail_bytes{mountpoint="/labdisk"} / node_filesystem_size_bytes{mountpoint="/labdisk"})
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100
rate(node_cpu_seconds_total{mode="idle"}[5m])
100 * (1 - avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[5m])))
```

The `node_cpu_seconds_total` metric is a counter of accumulated CPU seconds, not a utilization percentage. `rate(...[5m])` estimates its per-second increase using a five-minute sample window; `avg by(instance)` combines logical CPU series. Labels such as `job`, `instance` and `mountpoint` select and group series.

## Incident A — disk pressure

**Reproduction:**

```bash
cd monitoring/prometheus
docker compose run --rm -T disk-writer -c 'dd if=/dev/zero of=/labdisk/fill.bin bs=1M count=54 && df -h /labdisk'
```

Rule: `LabDiskAlmostFull`, disk usage `> 80`, `for: 30s`, `severity: warning`.

**Observed:** the filesystem rose to 84.375%; Prometheus displayed Pending and then Firing. Alertmanager received the alert and forwarded the JSON to `http://alert-echo:8080/alerts`. The receiver is readable on the host at **`http://127.0.0.1:8081/alerts`** (the root `/` is not a UI endpoint).

**Recovery:**

```bash
docker compose run --rm -T disk-writer -c 'rm -f /labdisk/fill.bin && df -h /labdisk'
```

Observed event fields (UTC, from captured webhook JSON):

| Field | Value |
| --- | --- |
| Firing payload `startsAt` | 2026-10-22 14:48:49.323 |
| Firing webhook `received_at` | 2026-10-22 14:48:59.342 |
| Resolved payload `endsAt` | 2026-10-22 14:55:04.323 |
| Resolved webhook `received_at` | 2026-10-22 14:55:14.401 |
| Per-payload timestamp gap | ~10 seconds in both cases |

**Timing caution:** Prometheus' `startsAt` is the alert's active-since timestamp; it must not be treated as a direct timestamp of transition to Firing. Therefore the observed 10-second differences cannot independently establish precise detection-to-Firing latency. Scrape/evaluation phase, `for: 30s`, `group_wait: 10s` and grouping all affect delivery.

A compact machine-readable extract is saved in [day2-webhook-evidence.json](evidence/day2-webhook-evidence.json).

## Incident B — target unavailable

```bash
docker compose stop node-exporter
# Confirm node target DOWN and TargetDown firing (critical).
docker compose start node-exporter
```

During the outage, the Targets page displayed a scrape failure involving Docker DNS (`lookup node-exporter on 127.0.0.11:53: no such host`); `prometheus` itself stayed UP. A separate Prometheus screenshot showed `TargetDown` Firing, `instance=lab-host`, `severity=critical`, and `up{job="node"} == 0`. Stopping a container can remove its Docker DNS registration: the symptom is not evidence of a general DNS misconfiguration.

## Inhibition verification

Configuration:

```yaml
inhibit_rules:
  - source_matchers: [ 'alertname="TargetDown"' ]
    target_matchers: [ 'severity="warning"' ]
    equal: [instance]
```

Two **synthetic** alerts were POSTed to the Alertmanager v2 API, sharing `instance=lab-inhibition-demo`. Alertmanager returned HTTP 200. Its subsequent API response was:

```text
TargetDown active []
DemoWarning suppressed ['4482be62f05b73e3']
```

This directly verifies the suppression state: the warning remains present but is inhibited by the active critical alert. It does **not** mean Prometheus itself suppressed a rule, or prove that a webhook for the warning was never sent (that latter detail was not checked).

## Grafana provisioning

The file-provisioned dashboard **Infra Lab — Node & Alerting** showed five panels: Target health, Lab disk used (%), CPU busy (%), Available memory (%), and Firing alert count. The observed plots showed the disk filling and clearing, plus node_exporter downtime and recovery. All panels remained after restarting Grafana, confirming provisioning/persistence across a service restart.

Dashboard source: [infra-lab-overview.json](../monitoring/prometheus/grafana/dashboards/infra-lab-overview.json).

## Zabbix vs Prometheus — learned from the labs

| Topic | Zabbix (Day 1) | Prometheus stack (Day 2) |
| --- | --- | --- |
| Collection | Zabbix Agent passive checks; Zabbix also supports active checks | Prometheus scrapes exporter HTTP endpoints |
| Storage | PostgreSQL in our Compose lab | Prometheus TSDB in a named volume |
| Rule | Host Item + Trigger expression, configured through Zabbix UI | YAML alert expression with explicit `for` |
| Notification | Actions/media types (not tested in Day 1) | Alertmanager routes to observed webhook receiver |
| Reproducibility | UI-created configuration needs proper export/import verification | Metrics, alert rules and Grafana provisioning tracked as files |
| Incident observation | 30 s was the **duration** of the recorded disk event, not measured detection latency | Pending/Firing and webhook timestamps captured, no exact end-to-end detection latency measured |

Neither is universally better: Zabbix includes broad server/network management features; Prometheus excels at labeled time-series metrics, PromQL and cloud-native workflows. The two can complement each other.

## Limitations / next improvements

- The dashboards visualize existing data but do not constitute a full benchmark of sustained production load.
- node_exporter exposes kernel metrics and its own container-visible mounts; `/labdisk` is a **test tmpfs volume**, not the real Kali root filesystem. Do not describe this as complete Kali host disk monitoring.
- The webhook receiver keeps events only in memory; restarting it loses recorded events.
- Synthetic inhibition was tested via Alertmanager's API, not an independently failing production service.
- Screenshot files from the interactive session were not automatically committed; the structured webhook extract, configs and observations are available in the repository.
- Consider later adding automated smoke tests, version/pinning policy, resilient receiver storage, and a clean-room deployment test.
