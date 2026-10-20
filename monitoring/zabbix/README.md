# Zabbix 7.0 LTS — Local monitoring lab

Deploy: `docker compose up -d`, from this directory, after creating a private `.env` (`ZBX_DB_PASSWORD`).

Web: <http://127.0.0.1:8080> (`Admin` / `zabbix` initially; change immediately).

Services: PostgreSQL 16, Zabbix Server, Nginx Web UI and Zabbix Agent 2. The agent monitors its container.

Project name is pinned to `zabbix-lab` to reuse the existing `zabbix-lab_zbx-pgdata` volume after moving the Compose file.

Create a host named `lab-host`, link `Linux by Zabbix agent`, and configure agent interface port `10050`.

The original lab used Docker DNS `zabbix-agent` but hit a Zabbix-side resolution error; `172.18.0.5` worked as a **temporary** diagnostic address. That IP is not portable.

Original exported custom template: [`templates/lab-disk-monitoring-original.yaml`](templates/lab-disk-monitoring-original.yaml) — **item only**.

Derived candidate template: [`templates/lab-disk-monitoring-with-trigger.yaml`](templates/lab-disk-monitoring-with-trigger.yaml) — manually adds the high-severity trigger. It is **not yet import-tested**. Do not link it to `lab-host` before removing/replacing the existing host-level item with the same key.

Smoke check: from the repository root run `bash scripts/check-zabbix.sh`.

Incident and recovery: [Scenario 01](../../scenarios/01-disk-full.md). Existing lab migration: [adoption guide](../../docs/adopt-existing-lab.md).
