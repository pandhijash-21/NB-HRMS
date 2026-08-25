#!/usr/bin/env bash
# Native (non-Docker) production start for Render
set -euo pipefail
npx prisma generate
npx prisma migrate deploy
exec node dist/index.js
