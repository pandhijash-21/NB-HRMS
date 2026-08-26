#!/bin/sh
# Run on the Hostinger VPS after CI has rsynced files into /opt/nb-crm.
# Rebuilds API + web only. Never seeds. Never db-push / accept-data-loss.
set -eu

ROOT=/opt/nb-crm
COMPOSE="$ROOT/docker-compose.prod.yml"
ENV_FILE="$ROOT/backend/.env.production"

cd "$ROOT"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing $ENV_FILE — SMTP/JWT live only on the server. Aborting."
  exit 1
fi

# Orphan leftover that failed a previous TypeScript build
rm -f "$ROOT/backend/src/middleware/vpnBlock.ts"

sed -i 's/\r$//' "$ROOT/backend/docker/entrypoint.sh" 2>/dev/null || true
chmod +x "$ROOT/backend/docker/entrypoint.sh" 2>/dev/null || true

echo "==> Rebuild backend + recreate frontend (postgres/redis stay up)"
docker compose -f "$COMPOSE" --env-file "$ENV_FILE" up -d --build backend
docker compose -f "$COMPOSE" --env-file "$ENV_FILE" up -d --force-recreate frontend

echo "==> Wait for API"
i=0
until curl -fsS http://127.0.0.1:4000/health >/dev/null 2>&1; do
  i=$((i + 1))
  if [ "$i" -ge 30 ]; then
    echo "API health check timed out"
    docker compose -f "$COMPOSE" logs --tail=80 backend
    exit 1
  fi
  sleep 2
done

echo "==> Status"
docker compose -f "$COMPOSE" ps
curl -fsS http://127.0.0.1:4000/health
echo
echo "==> Hostinger apply done"
