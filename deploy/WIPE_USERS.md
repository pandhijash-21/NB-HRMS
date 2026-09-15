# Wipe users + employee-related data

Keeps **SUPERADMIN** + **ADMIN** accounts, and **orgs / institutes / designations / roles**.

Deletes all other users and **all employees** (photos, attendance, leave, salary, docs, etc.).

## After you push + pipeline deploys

```bash
ssh YOUR_USER@YOUR_HOST
cd /opt/nb-crm

docker compose -f docker-compose.prod.yml --env-file backend/.env.production \
  exec -T -e CONFIRM_WIPE_USERS=YES backend \
  npx tsx scripts/wipe-user-data.ts

docker compose -f docker-compose.prod.yml --env-file backend/.env.production \
  exec -T redis redis-cli FLUSHDB

docker compose -f docker-compose.prod.yml --env-file backend/.env.production \
  exec -T postgres psql -U hrms_user -d nb_crm_db -c \
  "SELECT u.username, r.name AS role FROM users u JOIN roles r ON r.id = u.role_id ORDER BY 1;"
```

You should only see `superadmin` and company `ADMIN` usernames. `employees` count should be `0`.
