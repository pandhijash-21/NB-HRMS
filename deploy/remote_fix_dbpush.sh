sed -i 's/\r$//' /opt/nb-crm/backend/docker/entrypoint.sh
sed -i 's/npx prisma db push --skip-generate$/npx prisma db push --skip-generate --accept-data-loss/' /opt/nb-crm/backend/docker/entrypoint.sh
grep -n "db push" /opt/nb-crm/backend/docker/entrypoint.sh
cd /opt/nb-crm && docker compose -f docker-compose.prod.yml --env-file backend/.env.production up -d --build backend
sleep 12
docker compose -f docker-compose.prod.yml logs --tail=40 backend
echo '---HEALTH---'
curl -sS http://127.0.0.1:4000/health || true
