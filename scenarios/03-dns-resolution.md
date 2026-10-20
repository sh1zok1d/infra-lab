# Scenario 03 — Zabbix cannot resolve container DNS name

**State:** Workaround confirmed; root cause **not yet established**.

## Symptom

The Zabbix host interface configured with DNS `zabbix-agent` returned:

```text
Get value from agent failed: Cannot resolve address: Domain name not found
```

## Checks

Inside Zabbix Server:

```bash
sudo docker exec zbx-server getent hosts zabbix-agent
```

Observed result: `172.18.0.5 zabbix-agent zabbix-agent`. Agent logs showed a running process and hostname `lab-host`.

## Diagnostic workaround

For `lab-host`, set interface **Connect to = IP**, IP = `172.18.0.5`, port = `10050`. The ZBX status changed to green and item data appeared.

**Warning:** `172.18.0.5` was the observed ephemeral container IP. Do **not** hard-code it in the Compose file, template or general installation guide.

## Follow-up investigation

Inspect how Zabbix Server's own DNS resolver differs from `getent`, then restore name-based monitoring and confirm resilience after container recreation.
