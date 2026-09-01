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
  # Migrations below use idempotent SQL — safe to mark rolled-back and re-apply after deploy timeouts.
  for mig in \
    20260827120000_employee_view_scope \
    20260830120000_erp_projects \
    20260831120000_erp_work_orders; do
    echo "==> migrate resolve --rolled-back $mig (if failed)"
    npx prisma migrate resolve --rolled-back "$mig" 2>/dev/null || true
  done
}

echo "==> Apply pending migrations only (no data-loss / no db push)"
# Additive migrations only — never use --accept-data-loss on Hostinger prod.
if ! npx prisma migrate deploy; then
  echo "==> migrate deploy failed — unstick idempotent migrations and retry"
  unstick_idempotent_migrations
  npx prisma migrate deploy
fi

echo "==> Starting API ($(date -Iseconds 2>/dev/null || date))"
exec node dist/index.js
