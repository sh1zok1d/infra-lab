# Adopt an existing Kali Zabbix deployment into this repository

**Do not use the proposed `mv ~/zabbix-lab/* ...` command.** It can leave your working deployment in an unexpected state. Git should store configuration, not runtime data or real secrets.

## Existing resources

Observed Docker Compose project: `zabbix-lab`. Its PostgreSQL volume is named `zabbix-lab_zbx-pgdata`. The Compose file in this repository declares `name: zabbix-lab`, so Compose will keep using the same project identity even from a new directory.

## Steps (run on Kali)

1. Extract the supplied archive to `~/infra-lab`, leaving `~/zabbix-lab` untouched for now.
2. Copy (do not regenerate) the existing database password file:

   ```bash
   cp ~/zabbix-lab/.env ~/infra-lab/monitoring/zabbix/.env
   chmod 600 ~/infra-lab/monitoring/zabbix/.env
   ```

3. Verify the new Compose uses the expected project and inspect its containers **without recreating** anything:

   ```bash
   cd ~/infra-lab/monitoring/zabbix
   sudo docker compose config --quiet
   sudo docker compose ls
   sudo docker compose ps
   sudo docker volume ls --filter name=zabbix-lab_zbx-pgdata
   ```

4. If all looks right, you may start managing the same project from this directory:

   ```bash
   sudo docker compose up -d
   ```

   Compose may recreate a service if its configuration changed. This should **not** delete the named database volume; confirm the UI still contains `lab-host`, the custom item and your trigger.

5. Keep the old directory until the new configuration is confirmed. Afterward you can archive or remove the old Compose folder, but **do not run `docker compose down -v`** in either location.

**Important:** Never execute `printf ... > .env` or copy `.env.example` over the real existing `.env`: changing the database password environment value does not update the password already stored in PostgreSQL.
