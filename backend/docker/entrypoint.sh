#!/bin/sh
set -e

echo "==> API entrypoint ($(date -Iseconds 2>/dev/null || date))"

# Client is generated in the Docker build; regenerating on every start can exceed deploy health timeouts.
if [ -f node_modules/.prisma/client/index.js ]; then
  echo "==> Prisma client present, skipping generate"
else
  echo "==> Prisma generate"
  npx prisma generate
fi

unstick_idempotent_migrations() {
  # Migrations below use idempotent SQL — safe to mark rolled-back and re-apply after deploy timeouts/failures.
  for mig in \
    20260827120000_employee_view_scope \
    20260830120000_erp_projects \
    20260831120000_erp_work_orders \
    20260901100000_meeting_chat_dm_participants \
    20260901150000_meeting_bhashini_transcript \
    20260910180000_add_user_deleted_at; do
    npx prisma migrate resolve --rolled-back "$mig" 2>/dev/null || true
  done
}

echo "==> Apply pending migrations only (no data-loss / no db push)"
# Auto-unstick idempotent migrations in case of any previously interrupted deployment
unstick_idempotent_migrations
if ! npx prisma migrate deploy; then
  echo "==> migrate deploy failed — retrying unstick and deploy"
  unstick_idempotent_migrations
  npx prisma migrate deploy
fi

echo "==> Starting API ($(date -Iseconds 2>/dev/null || date))"
exec node dist/index.js
