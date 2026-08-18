cd /opt/nb-crm
echo '---ORG SERVICE SOURCE---'
grep -n "syncFromLookups" backend/src/modules/organization/organization.service.ts || echo 'syncFromLookups removed from source'
docker compose -f docker-compose.prod.yml build --no-cache backend
docker compose -f docker-compose.prod.yml up -d backend
echo '---BACKEND STATUS---'
docker compose -f docker-compose.prod.yml ps backend
echo '---HEALTH---'
sleep 3
curl -sS --max-time 20 http://127.0.0.1:4000/health
echo
echo '---WEB JS GATE---'
curl -sS --max-time 20 https://crm.nbdeveloper.co.in/main.dart.js | grep -o "LOCATION REQUIRED" | head -1
echo
ls -l /opt/nb-crm/deploy/frontend/flutter_bootstrap.js /opt/nb-crm/deploy/frontend/main.dart.js
