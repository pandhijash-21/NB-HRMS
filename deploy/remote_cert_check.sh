cd /opt/nb-crm
docker compose -f docker-compose.prod.yml up -d frontend backend
sleep 20
echo '---CERT---'
echo | openssl s_client -connect crm.nbsince1946.com:443 -servername crm.nbsince1946.com 2>/dev/null | openssl x509 -noout -issuer -subject -dates || true
echo '---HTTPS STRICT---'
curl -sS --max-time 20 -o /dev/null -w '%{http_code}\n' https://crm.nbsince1946.com/health || true
curl -sS --max-time 20 -o /dev/null -w '%{http_code} %{content_type}\n' https://crm.nbsince1946.com/ || true
