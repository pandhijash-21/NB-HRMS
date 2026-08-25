#!/bin/sh
# Rebuild backend on Hostinger. Schema changes come from prisma migrate deploy
# in entrypoint.sh — never inject --accept-data-loss.
set -e
sed -i 's/\r$//' /opt/nb-crm/backend/docker/entrypoint.sh
grep -n "migrate deploy\|db push\|accept-data-loss" /opt/nb-crm/backend/docker/entrypoint.sh || true
cd /opt/nb-crm && docker compose -f docker-compose.prod.yml --env-file backend/.env.production up -d --build backend
sleep 12
docker compose -f docker-compose.prod.yml logs --tail=40 backend
echo '---HEALTH---'
curl -sS http://127.0.0.1:4000/health || true
