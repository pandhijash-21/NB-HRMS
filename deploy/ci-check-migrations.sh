#!/usr/bin/env bash
# CI gate: flag NEW Prisma migrations that look destructive.
# Scans only migration SQL files changed vs the comparison base (not historic migrations).
# Safe additive changes (ADD COLUMN, CREATE TABLE, CREATE INDEX) pass.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BASE_REF="${1:-}"
if [ -z "$BASE_REF" ]; then
  if git rev-parse --verify origin/main >/dev/null 2>&1; then
    BASE_REF="origin/main"
  elif git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
    BASE_REF="HEAD~1"
  else
    echo "No comparison base; skipping migration safety scan."
    exit 0
  fi
fi

# Empty / all-zero before SHA on first push of a branch
if [[ "$BASE_REF" =~ ^0+$ ]]; then
  echo "No previous commit range; scanning all migrations added in this commit tree is skipped."
  echo "Tip: open a PR against main so changed migrations are diffed."
  exit 0
fi

mapfile -t FILES < <(git diff --name-only --diff-filter=AM "$BASE_REF"...HEAD -- \
  'backend/prisma/migrations/**/*.sql' \
  'backend/prisma/migrations/*.sql' 2>/dev/null || true)

if [ "${#FILES[@]}" -eq 0 ] || [ -z "${FILES[0]:-}" ]; then
  echo "No new/changed Prisma migration SQL vs $BASE_REF — OK"
  exit 0
fi

echo "Checking migration files vs $BASE_REF:"
printf '  - %s\n' "${FILES[@]}"

# Patterns that usually mean data loss or irreversible schema removal.
# DROP INDEX / DROP CONSTRAINT alone are not flagged (often safe renames).
PATTERN='(\bDROP[[:space:]]+TABLE\b|\bDROP[[:space:]]+COLUMN\b|\bTRUNCATE[[:space:]]+(TABLE[[:space:]]+)?|\bDELETE[[:space:]]+FROM\b|\bmigrate[[:space:]]+reset\b|\baccept[-_]?data[-_]?loss\b|\bdb[[:space:]]+push\b)'

FAILED=0
for f in "${FILES[@]}"; do
  [ -f "$f" ] || continue
  cleaned=$(sed -E 's/--.*$//' "$f" | tr '\n' ' ')
  if echo "$cleaned" | grep -Eiq "$PATTERN"; then
    echo ""
    echo "BLOCKED: destructive-looking SQL in $f"
    echo "Review manually before merging/deploying. Additive migrations (e.g. ADD COLUMN) are fine."
    grep -Ein 'DROP[[:space:]]+TABLE|DROP[[:space:]]+COLUMN|TRUNCATE|DELETE[[:space:]]+FROM|migrate[[:space:]]+reset|accept.?data.?loss|db[[:space:]]+push' "$f" || true
    FAILED=1
  fi
done

if [ "$FAILED" -ne 0 ]; then
  echo ""
  echo "Migration safety check failed. Fix the migration or split destructive work into a manual ops change."
  exit 1
fi

echo "Migration safety check passed."
