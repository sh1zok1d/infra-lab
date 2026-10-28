# Scenario 04 — Prometheus disk alert and recovery

**Outcome:** PASS, 2026-10-22. Reproduced on a 64 MiB tmpfs `/labdisk` visible to the node_exporter container; **not** on the host root filesystem.

## Symptom and detection

Prometheus rule `LabDiskAlmostFull` becomes Pending when utilization exceeds 80%, then Firing if the expression stays true for 30 seconds. Observed ~84.375% after writing 54 MiB.

## Reproduce

```bash
cd monitoring/prometheus
docker compose run --rm -T disk-writer -c 'dd if=/dev/zero of=/labdisk/fill.bin bs=1M count=54 && df -h /labdisk'
```

Inspect <http://127.0.0.1:9090/alerts> and <http://127.0.0.1:9093>. For the delivered webhook, use **<http://127.0.0.1:8081/alerts>**, not `/` (which returns 404).

## Recovery

```bash
docker compose run --rm -T disk-writer -c 'rm -f /labdisk/fill.bin && df -h /labdisk'
```

Prometheus subsequently reported Inactive. Alertmanager delivered both `firing` and `resolved` JSON payloads. Captured times and interpretation: [Day 2 report](../docs/day2-prometheus.md#incident-a--disk-pressure).

## Operational lesson

A counter, scrape interval, rule evaluation and `for` duration are separate concerns. An alert's `startsAt` does not by itself prove exactly when Firing began. Do not infer an exact detection latency from screenshot timestamps alone.
