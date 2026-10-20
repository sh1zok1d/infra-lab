# Scenario 02 — Zabbix Agent 2 restart loop

**State:** Observed and resolved on 2026-10-20.

## Symptom

`docker compose ps -a` showed the agent restarting and `lab-host` had an unavailable agent interface.

## Evidence

The agent log included:

```text
Cannot validate configuration: failed to validate "Server" configuration parameter:
address "zabbix-server" specified more than once.
```

The Compose configuration included both `ZBX_SERVER_HOST: zabbix-server` and `ZBX_PASSIVESERVERS: zabbix-server`, producing `Server=zabbix-server,zabbix-server`.

## Repair

Remove the duplicate `ZBX_PASSIVESERVERS` setting from `zabbix-agent` environment and recreate the agent:

```bash
sudo docker compose up -d --force-recreate zabbix-agent
sudo docker compose ps
sudo docker compose logs --tail=30 zabbix-agent
```

## Result

The restart loop stopped and the agent initialized successfully. Name-based monitoring was subsequently restored after diagnosing the transient DNS symptom; see [Scenario 03](03-dns-resolution.md).
