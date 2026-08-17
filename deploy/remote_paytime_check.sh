cd /opt/nb-crm
echo '---TAILSCALE---'
tailscale status
echo '---HOST TCP---'
timeout 5 bash -c 'cat < /dev/null > /dev/tcp/192.168.1.145/55304' && echo host_ok || echo host_fail
echo '---DOCKER TCP---'
docker compose -f docker-compose.prod.yml exec -T backend sh -c 'timeout 5 bash -c "cat < /dev/null > /dev/tcp/192.168.1.145/55304" && echo docker_ok || echo docker_fail'
echo '---BACKEND HEALTH---'
curl -sS http://127.0.0.1:4000/health
