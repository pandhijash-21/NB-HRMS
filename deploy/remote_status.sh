sleep 8
cd /opt/nb-crm
docker compose -f docker-compose.prod.yml ps
echo '---LOGS---'
docker compose -f docker-compose.prod.yml logs --tail=60 backend
echo '---HEALTH---'
curl -sS http://127.0.0.1:4000/health || true
