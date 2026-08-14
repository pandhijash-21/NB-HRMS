cd /opt/nb-crm
rm -rf deploy/frontend
mkdir -p deploy/frontend
tar xf nbcrm-web.tar -C deploy/frontend
ls -la deploy/frontend | head
docker compose -f docker-compose.prod.yml restart frontend
sleep 2
docker compose -f docker-compose.prod.yml ps
echo '---IP HEALTH---'
curl -sS http://127.0.0.1:4000/health
echo
echo '---HTTPS HEALTH---'
curl -sS -k --max-time 20 https://crm.nbdeveloper.co.in/health || true
echo
echo '---HTTPS ROOT---'
curl -sS -k --max-time 20 -o /dev/null -w '%{http_code} %{content_type}\n' https://crm.nbdeveloper.co.in/ || true
echo '---HTTP ROOT---'
curl -sS --max-time 15 -o /dev/null -w '%{http_code} redirect:%{redirect_url}\n' http://crm.nbdeveloper.co.in/ || true
docker logs traefik-traefik-1 --tail 30 2>&1 | tail -30
