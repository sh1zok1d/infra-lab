# Scenario 05 — node_exporter unavailable

**Outcome:** PASS, 2026-10-22. This simulates a missing scrape target, not a complete Linux host power failure.

## Reproduce

```bash
cd monitoring/prometheus
docker compose stop node-exporter
```

The target `node` changed to DOWN, while Prometheus remained UP. The observed scrape error referred to Docker DNS (`lookup node-exporter on 127.0.0.11:53: no such host`) because the stopped container lost its network endpoint. The rule `up{job="node"} == 0` entered Firing after its 30-second `for`.

## Recover and verify

```bash
docker compose start node-exporter
```

Check <http://127.0.0.1:9090/targets> for UP and <http://127.0.0.1:9090/alerts> for the rule returning to Inactive. Avoid assuming all other alerts are inhibited: disappearing metrics can cause separate alert expressions to cease evaluating true.

## Operational lesson

Differentiate scrape failure, application outage and DNS resolution symptoms. Exporter unavailability is a monitoring-target failure, not necessarily a failure of the underlying machine.
