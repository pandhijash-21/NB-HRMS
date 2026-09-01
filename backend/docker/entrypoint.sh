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

echo "==> Apply pending migrations only (no data-loss / no db push)"
# Additive migrations only — never use --accept-data-loss on Hostinger prod.
if ! npx prisma migrate deploy; then
  echo "==> migrate deploy failed — unstick failed 20260827120000_employee_view_scope (SQL is idempotent)"
  npx prisma migrate resolve --rolled-back 20260827120000_employee_view_scope || true
  npx prisma migrate deploy
fi

echo "==> Starting API ($(date -Iseconds 2>/dev/null || date))"
exec node dist/index.js
