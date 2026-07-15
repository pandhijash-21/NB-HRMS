#!/usr/bin/env bash
# Create nb_crm_db (if missing) and apply Prisma migrations.
# Does NOT drop, alter, or read from hrms_db.
# Reuses any Postgres already bound to localhost:5434 (e.g. college HRMS stack).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_NAME="nb_crm_db"
DB_USER="hrms_user"
DATABASE_URL="${DATABASE_URL:-postgres://hrms_user:hrms_pass@localhost:5434/${DB_NAME}}"

get_postgres_container() {
  docker ps --filter "publish=5434" --format "{{.Names}}" | head -n 1
}

cd "$ROOT_DIR"

PG_CONTAINER="$(get_postgres_container || true)"
if [ -z "${PG_CONTAINER}" ]; then
  echo "==> No Postgres on port 5434; starting this project's postgres service..."
  docker compose up -d postgres
  echo "==> Waiting for Postgres to accept connections..."
  for i in $(seq 1 30); do
    PG_CONTAINER="$(get_postgres_container || true)"
    if [ -n "${PG_CONTAINER}" ] && docker exec "$PG_CONTAINER" pg_isready -U "$DB_USER" >/dev/null 2>&1; then
      break
    fi
    if [ "$i" -eq 30 ]; then
      echo "ERROR: Postgres did not become ready in time." >&2
      exit 1
    fi
    sleep 1
  done
else
  echo "==> Reusing existing Postgres container on port 5434: ${PG_CONTAINER}"
  docker exec "$PG_CONTAINER" pg_isready -U "$DB_USER" >/dev/null
fi

echo "==> Creating database '${DB_NAME}' if it does not exist (hrms_db is left untouched)..."
EXISTS="$(docker exec "$PG_CONTAINER" psql -U "$DB_USER" -d postgres -Atc \
  "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}'")"
if [ "$EXISTS" = "1" ]; then
  echo "    Database '${DB_NAME}' already exists - skipping CREATE."
else
  docker exec "$PG_CONTAINER" psql -U "$DB_USER" -d postgres -c \
    "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"
  echo "    Created database '${DB_NAME}'."
fi

echo "==> Applying Prisma migrations to '${DB_NAME}' only..."
cd "$ROOT_DIR/backend"
export DATABASE_URL
npx prisma migrate deploy

echo "==> Done. DATABASE_URL for this project should be:"
echo "    ${DATABASE_URL}"
echo "==> College DB hrms_db was not modified."
