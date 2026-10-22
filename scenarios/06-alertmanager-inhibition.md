# Scenario 06 — Alertmanager inhibition

**Outcome:** PASS, 2026-10-22. This is an explicit **synthetic API test** of Alertmanager rules, not a real simultaneous server and disk outage.

## Hypothesis

A critical `TargetDown` alert on an instance suppresses notifications from warning-severity alerts on the **same `instance`**. The suppressed alert remains visible in Alertmanager.

## Reproduce

```bash
curl -sS -o /dev/null -w 'HTTP %{http_code}\n' \
  -X POST http://127.0.0.1:9093/api/v2/alerts \
  -H 'Content-Type: application/json' \
  -d '[
    {"labels":{"alertname":"TargetDown","instance":"lab-inhibition-demo","severity":"critical"}},
    {"labels":{"alertname":"DemoWarning","instance":"lab-inhibition-demo","severity":"warning"}}
  ]'

curl -sS http://127.0.0.1:9093/api/v2/alerts | python3 -c '
import json,sys
for a in json.load(sys.stdin):
    if a["labels"].get("instance")=="lab-inhibition-demo":
        print(a["labels"]["alertname"],a["status"]["state"],a["status"].get("inhibitedBy"))
'
```

## Observed

```text
HTTP 200
TargetDown active []
DemoWarning suppressed ['4482be62f05b73e3']
```

The `inhibitedBy` entry is direct evidence that a matching active source alert suppressed `DemoWarning`. The exact identifier will vary across runs. The receiver's negative evidence (absence of a `DemoWarning` webhook) was not separately recorded.

## Operational lesson

Alertmanager inhibition affects **notification routing**, not the truth value of Prometheus alert rules. `equal: [instance]` limits suppression to the matching target.
