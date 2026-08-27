#!/bin/sh
# Run on the Hostinger VPS after CI has rsynced files into /opt/nb-crm.
# Rebuilds API + web only. Never seeds. Never db-push / accept-data-loss.
#
# Env (optional):
#   DEPLOY_SHA          Git commit SHA for this release
#   PUBLIC_HEALTH_URL   default https://crm.nbdeveloper.co.in/health
#   PUBLIC_FRONTEND_URL default https://crm.nbdeveloper.co.in/
set -eu

ROOT=/opt/nb-crm
COMPOSE="$ROOT/docker-compose.prod.yml"
ENV_FILE="$ROOT/backend/.env.production"
SHA="${DEPLOY_SHA:-unknown}"
PUBLIC_HEALTH_URL="${PUBLIC_HEALTH_URL:-https://crm.nbdeveloper.co.in/health}"
PUBLIC_FRONTEND_URL="${PUBLIC_FRONTEND_URL:-https://crm.nbdeveloper.co.in/}"
# Probe path without VPN auth_request (curl from the VPS uses a hosting IP and would get 403→404).
PUBLIC_FRONTEND_HEALTH_URL="${PUBLIC_FRONTEND_HEALTH_URL:-https://crm.nbdeveloper.co.in/frontend-health}"
BACKEND_IMAGE_REPO="nb-crm-backend"
PREV_IMAGE_FILE="$ROOT/.deploy-prev-backend-image"
CURRENT_SHA_FILE="$ROOT/.deploy-current-sha"
PREV_SHA_FILE="$ROOT/.deploy-previous-sha"
FRONTEND_PREV="$ROOT/deploy/frontend.prev"

cd "$ROOT"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing $ENV_FILE — SMTP/JWT live only on the server. Aborting."
  exit 1
fi

sed -i 's/\r$//' "$ROOT/backend/docker/entrypoint.sh" 2>/dev/null || true
chmod +x "$ROOT/backend/docker/entrypoint.sh" 2>/dev/null || true

# Ensure VPN deny page exists in the nginx docroot (volume bind can also mount it).
if [ -f "$ROOT/deploy/nginx/vpn-blocked.html" ]; then
  cp -f "$ROOT/deploy/nginx/vpn-blocked.html" "$ROOT/deploy/frontend/vpn-blocked.html"
fi

compose() {
  docker compose -f "$COMPOSE" --env-file "$ENV_FILE" "$@"
}

rollback() {
  echo "==> HEALTH FAILED — rolling back app/frontend (DB migrations are NOT reverted)"
  if [ -d "$FRONTEND_PREV" ]; then
    echo "Restoring previous frontend from deploy/frontend.prev"
    rm -rf "$ROOT/deploy/frontend"
    cp -a "$FRONTEND_PREV" "$ROOT/deploy/frontend"
  fi
  if [ -f "$ROOT/deploy/nginx/vpn-blocked.html" ]; then
    mkdir -p "$ROOT/deploy/frontend"
    cp -f "$ROOT/deploy/nginx/vpn-blocked.html" "$ROOT/deploy/frontend/vpn-blocked.html"
  fi

  if [ -f "$PREV_IMAGE_FILE" ]; then
    prev_img=$(cat "$PREV_IMAGE_FILE" 2>/dev/null || true)
    if [ -n "$prev_img" ] && docker image inspect "$prev_img" >/dev/null 2>&1; then
      echo "Restoring previous backend image: $prev_img"
      docker tag "$prev_img" "${BACKEND_IMAGE_REPO}:latest" || true
      compose up -d backend || true
    else
      echo "No usable previous backend image to restore"
    fi
  fi

  # Old backend images may lack /vpn-gate; new nginx auth_request then 500s the whole site.
  gate_code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:4000/vpn-gate || echo 000)
  case "$gate_code" in
    204|403) ;;
    *)
      echo "vpn-gate unavailable (HTTP $gate_code) — writing nginx conf without auth_request"
      cat > "$ROOT/deploy/nginx/frontend.conf" <<'EOF'
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;
    location = /frontend-health {
        access_log off;
        default_type text/plain;
        return 200 'ok\n';
    }
    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF
      ;;
  esac

  compose up -d --force-recreate frontend || true

  echo "==> Rollback attempted. Inspect logs; DB schema left as migrate deploy applied it."
  compose logs --tail=80 backend || true
  exit 1
}

echo "==> Deploy SHA: $SHA"

# Remember currently running backend image for rollback (before rebuild)
if docker inspect --format='{{.Image}}' nb-crm-backend-1 >/dev/null 2>&1; then
  docker inspect --format='{{.Image}}' nb-crm-backend-1 > "$PREV_IMAGE_FILE"
  echo "Previous backend image id saved"
fi

echo "==> Rebuild backend + recreate frontend (postgres/redis stay up; volumes untouched)"
compose build backend
# Tag release for traceability (and keep :latest for compose)
if docker image inspect "${BACKEND_IMAGE_REPO}:latest" >/dev/null 2>&1; then
  docker tag "${BACKEND_IMAGE_REPO}:latest" "${BACKEND_IMAGE_REPO}:${SHA}" || true
fi
compose up -d backend
compose up -d --force-recreate frontend

echo "==> Wait for local API health"
i=0
until curl -fsS http://127.0.0.1:4000/health >/dev/null 2>&1; do
  i=$((i + 1))
  if [ "$i" -ge 30 ]; then
    echo "Local API health check timed out"
    rollback
  fi
  sleep 2
done

echo "==> Verify containers"
compose ps
for c in nb-crm-backend-1 nb-crm-frontend-1 nb-crm-postgres-1 nb-crm-redis-1; do
  st=$(docker inspect -f '{{.State.Status}}' "$c" 2>/dev/null || echo missing)
  echo "$c status=$st"
  if [ "$st" != "running" ]; then
    echo "Container $c is not running"
    rollback
  fi
done

echo "==> Public health: $PUBLIC_HEALTH_URL"
if ! curl -fsS -k --max-time 25 "$PUBLIC_HEALTH_URL" >/dev/null; then
  echo "Public API health failed"
  rollback
fi

echo "==> Public frontend health: $PUBLIC_FRONTEND_HEALTH_URL"
# Do not curl / — VPS egress is often flagged hosting/proxy and auth_request returns 403.
code=$(curl -sS -k --max-time 25 -o /dev/null -w '%{http_code}' "$PUBLIC_FRONTEND_HEALTH_URL" || echo 000)
case "$code" in
  200|301|302|304) echo "Frontend health HTTP $code OK" ;;
  *)
    echo "Frontend health not reachable (HTTP $code)"
    # Fallback: in-container check (bypasses Traefik; still exercises nginx).
    if compose exec -T frontend wget -q -O - http://127.0.0.1/frontend-health 2>/dev/null | grep -q ok; then
      echo "Frontend health OK via container (public probe failed with HTTP $code)"
    else
      rollback
    fi
    ;;
esac

# Promote SHA markers only after success
if [ -f "$CURRENT_SHA_FILE" ]; then
  cp "$CURRENT_SHA_FILE" "$PREV_SHA_FILE"
fi
echo "$SHA" > "$CURRENT_SHA_FILE"
echo "$SHA" > "$ROOT/deploy/frontend/deploy-sha.txt" 2>/dev/null || true

curl -fsS http://127.0.0.1:4000/health
echo
echo "==> Hostinger apply done (SHA $SHA). DB data preserved; migrate deploy only."
