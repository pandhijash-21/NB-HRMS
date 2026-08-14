cd /opt/nb-crm
docker compose -f docker-compose.prod.yml exec -T backend npx prisma db seed
echo '---SEED DONE---'
