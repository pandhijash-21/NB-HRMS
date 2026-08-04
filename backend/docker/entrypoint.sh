#!/bin/sh
set -e

echo "==> Prisma generate"
npx prisma generate

echo "==> Sync schema to database (migrate deploy + db push for schema drift)"
# Existing migration history may lag the schema; db push keeps Neon in sync for temp hosting.
npx prisma migrate deploy || echo "migrate deploy skipped/failed — continuing with db push"
npx prisma db push --skip-generate

echo "==> Starting API"
exec node dist/index.js
