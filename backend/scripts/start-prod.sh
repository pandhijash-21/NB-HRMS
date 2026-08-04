#!/usr/bin/env bash
# Native (non-Docker) production start for Render
set -euo pipefail
npx prisma generate
npx prisma migrate deploy || echo "migrate deploy: continuing"
npx prisma db push --skip-generate
exec node dist/index.js
