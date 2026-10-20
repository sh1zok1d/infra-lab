# Zabbix 7.0 LTS

Four Compose services: PostgreSQL 16, Zabbix Server, Web UI and Agent 2. The agent monitors its own container and an isolated `/labdisk` tmpfs (64 MiB).

## Run

```bash
printf 'ZBX_DB_PASSWORD=%s\n' "$(openssl rand -hex 24)" > .env
chmod 600 .env
docker compose up -d
```

Open <http://127.0.0.1:8080> (`Admin` / `zabbix` initially; change the password).

Create `lab-host` with the `Linux by Zabbix agent` template and Agent interface DNS `zabbix-agent`, port `10050`. Create an item with key `vfs.fs.size[/labdisk,pused]` (float, 30s) and a High trigger `last(/lab-host/vfs.fs.size[/labdisk,pused])>80`.

- [Original template export](templates/lab-disk-monitoring-original.yaml) — custom item only.
- [Derived template with trigger](templates/lab-disk-monitoring-with-trigger.yaml) — a draft that **has not been import-tested**. Do not import it on top of a host item with the same key without resolving the conflict.

Run the [disk-full test](../../scenarios/01-disk-full.md) and review the [Day 1 report](../../docs/day1-zabbix.md). Telegram delivery was confirmed by the operator; its UI configuration is not part of Compose.
