#!/bin/sh
set -e

echo "==> Prisma generate"
npx prisma generate

echo "==> Apply pending migrations only (no data-loss / no db push)"
# Additive migrations only — never use --accept-data-loss on Hostinger prod.
npx prisma migrate deploy

echo "==> Starting API"
exec node dist/index.js
