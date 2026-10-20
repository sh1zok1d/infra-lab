# Scenario 03 — Transient container DNS error

**State:** Resolved; name-based agent monitoring restored (operator-confirmed).

## Symptom

While the Zabbix Agent 2 container was in a restart loop, Zabbix showed:

```text
Get value from agent failed: Cannot resolve address: Domain name not found
```

## Investigation

The agent had been restarting because its `Server` configuration included `zabbix-server` twice ([Scenario 02](02-agent-crash-loop.md)). This made the agent endpoint intermittently unavailable during restarts, consistent with the DNS symptom.

After fixing the agent configuration, a shell lookup from Zabbix Server succeeded:

```bash
docker exec zbx-server getent hosts zabbix-agent
# observed: 172.18.0.5 zabbix-agent zabbix-agent
```

The Zabbix UI still initially displayed an unavailable interface. Temporarily switching the host interface to `172.18.0.5:10050` turned ZBX green, proving the agent was reachable.

## Resolution

Once the agent was stable, the host interface was returned to **Connect to = DNS**, DNS name `zabbix-agent`, port `10050`. Name-based monitoring is reported working by the operator.

**Root cause:** the agent restart loop caused an unstable service endpoint; the timing and cache behavior of Zabbix's own resolver were not separately captured. Treat the crash loop as the confirmed underlying failure and the DNS error as its observed symptom, rather than inventing an unverified resolver bug.

Do **not** hard-code `172.18.0.5`: container IP addresses can change.
