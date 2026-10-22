# Incident runbooks

Each runbook documents the observed symptom, checks, reproduction, recovery, and limitations.

## Zabbix — Day 1

- [01 — Disk-full alert and automatic recovery](01-disk-full.md)
- [02 — Agent crash loop: duplicate server setting](02-agent-crash-loop.md)
- [03 — Container DNS resolution and temporary IP workaround](03-dns-resolution.md)

## Prometheus / Alertmanager — Day 2

- [04 — Disk pressure, webhook delivery and resolved state](04-prometheus-disk-full.md)
- [05 — Exporter DOWN and TargetDown alert](05-node-exporter-down.md)
- [06 — Explicit inhibition test with synthetic alerts](06-alertmanager-inhibition.md)

Related reports: [Day 1](../docs/day1-zabbix.md) · [Day 2](../docs/day2-prometheus.md).
