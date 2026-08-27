#!/bin/bash
set -euo pipefail

cd /opt/nb-crm

echo "==> Ensure TRANSPORT_SECRET in backend/.env.production"
SECRET="${TRANSPORT_SECRET:-nb-crm-double-enc-v2-local}"
if grep -q '^TRANSPORT_SECRET=' backend/.env.production 2>/dev/null; then
  sed -i "s|^TRANSPORT_SECRET=.*|TRANSPORT_SECRET=${SECRET}|" backend/.env.production
else
  echo "TRANSPORT_SECRET=${SECRET}" >> backend/.env.production
fi

if grep -q '^VPN_BLOCK_ENABLED=' backend/.env.production 2>/dev/null; then
  sed -i 's|^VPN_BLOCK_ENABLED=.*|VPN_BLOCK_ENABLED=true|' backend/.env.production
else
  echo "VPN_BLOCK_ENABLED=true" >> backend/.env.production
fi

echo "==> Apply SQL migrations (idempotent)"
docker compose -f docker-compose.prod.yml exec -T postgres \
  psql -U hrms_user -d nb_crm_db < backend/prisma/add_login_lock.sql || true
docker compose -f docker-compose.prod.yml exec -T postgres \
  psql -U hrms_user -d nb_crm_db < backend/prisma/add_work_tasks.sql || true
docker compose -f docker-compose.prod.yml exec -T postgres \
  psql -U hrms_user -d nb_crm_db < backend/prisma/add_work_task_subtasks.sql || true

echo "==> Install VPN block page and flush VPN cache"
mkdir -p deploy/frontend
if [ -f deploy/nginx/vpn-blocked.html ]; then
  install -m 644 deploy/nginx/vpn-blocked.html deploy/frontend/vpn-blocked.html
fi
docker compose -f docker-compose.prod.yml exec -T redis sh -c \
  "redis-cli --raw KEYS 'vpnblock:v1:*' | while read -r k; do [ -n \"\$k\" ] && redis-cli DEL \"\$k\"; done" || true

echo "==> Reload frontend nginx (VPN gate)"
docker compose -f docker-compose.prod.yml restart frontend

echo "==> Rebuild backend"
docker compose -f docker-compose.prod.yml build backend
docker compose -f docker-compose.prod.yml up -d backend

sleep 4
echo "==> Health"
curl -sS http://127.0.0.1:4000/health || true
echo
docker compose -f docker-compose.prod.yml ps backend frontend
echo "DONE"
