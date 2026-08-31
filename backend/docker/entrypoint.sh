#!/bin/sh
set -e

echo "==> Prisma generate"
npx prisma generate

echo "==> Apply pending migrations only (no data-loss / no db push)"
# Additive migrations only — never use --accept-data-loss on Hostinger prod.
if ! npx prisma migrate deploy; then
  echo "==> migrate deploy failed — unstick failed 20260827120000_employee_view_scope (SQL is idempotent)"
  npx prisma migrate resolve --rolled-back 20260827120000_employee_view_scope || true
  npx prisma migrate deploy
fi

echo "==> Starting API"
exec node dist/index.js
