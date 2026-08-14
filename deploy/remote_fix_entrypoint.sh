sed -i 's/\r$//' /opt/nb-crm/backend/docker/entrypoint.sh
sed -i 's/\r$//' /opt/nb-crm/backend/Dockerfile.prod
python3 << 'PY'
from pathlib import Path
p = Path("/opt/nb-crm/backend/Dockerfile.prod")
t = p.read_text()
t = t.replace(
    "RUN chmod +x ./entrypoint.sh",
    r'RUN sed -i "s/\r$//" ./entrypoint.sh && chmod +x ./entrypoint.sh',
)
t = t.replace('CMD ["./entrypoint.sh"]', 'CMD ["sh", "./entrypoint.sh"]')
p.write_text(t)
print("dockerfile updated")
print(t.splitlines()[-6:])
PY
cd /opt/nb-crm && docker compose -f docker-compose.prod.yml --env-file backend/.env.production up -d --build backend
