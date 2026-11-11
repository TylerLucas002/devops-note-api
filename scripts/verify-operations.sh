#!/usr/bin/env bash
# Destructive drills are restricted to an explicitly isolated Compose project.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
[[ ${COMPOSE_PROJECT_NAME:-} == note-check-* ]] || { echo 'Use a unique COMPOSE_PROJECT_NAME beginning note-check-' >&2; exit 1; }
export APP_CONTAINER_NAME="$COMPOSE_PROJECT_NAME-app" DB_CONTAINER_NAME="$COMPOSE_PROJECT_NAME-db"
export APP_PORT=${APP_PORT:-13000} APP_BIND_ADDRESS=127.0.0.1
export MONGO_URI=mongodb://db:27017/notedb DB_NAME=notedb
export APP_VERSION=${APP_VERSION:-operations-check}
export APP_IMAGE=${APP_IMAGE:-devops-note-api:review}
export BACKUP_DIR="$(mktemp -d "$PWD/work/backup-test-XXXXXX")"
base="http://127.0.0.1:$APP_PORT"
cleanup() {
  docker compose logs --no-color --tail 30 app db || true
  docker compose down -v --remove-orphans || true
}
trap cleanup EXIT
wait_healthy() { docker compose up -d --no-build --wait --wait-timeout 120; }
wait_healthy
bash scripts/smoke-test.sh "$base" "$APP_VERSION"
note=$(curl -fsS "$base/notes" -H 'Content-Type: application/json' -d '{"title":"restore-proof","content":"isolated recovery test","category":"DevOps"}')
id=$(python3 -c 'import json,sys;print(json.loads(sys.argv[1])["_id"])' "$note")
bash scripts/backup.sh
archive=$(find "$BACKUP_DIR" -name '*.archive.gz' -type f | head -n 1)
curl -fsS -X DELETE "$base/notes/$id" >/dev/null
CONFIRM_RESTORE=yes bash scripts/restore.sh "$archive"
curl -fsS "$base/notes" | python3 -c 'import json,sys; notes=json.load(sys.stdin); assert any(n["_id"]==sys.argv[1] and n["content"]=="isolated recovery test" for n in notes)' "$id"
echo 'PASS backup-delete-restore: original ID and content recovered'
# Corrupt backup must fail before touching the running app.
printf 'corrupt' >> "$archive"
if CONFIRM_RESTORE=yes bash scripts/restore.sh "$archive"; then echo 'Corrupt backup was accepted' >&2; exit 1; fi
bash scripts/smoke-test.sh "$base" "$APP_VERSION"
echo 'PASS checksum rejection: app remained available'

docker compose stop app
if curl -fsS --max-time 3 "$base/health" >/dev/null 2>&1; then echo 'App unexpectedly available' >&2; exit 1; fi
wait_healthy
bash scripts/smoke-test.sh "$base" "$APP_VERSION"
echo 'PASS incident 1: stopped app detected and recovered'

docker compose stop db
for attempt in {1..10}; do
  status=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$base/health")
  [[ "$status" == 503 ]] && break
  sleep 1
done
[[ "$status" == 503 ]]
if bash scripts/backup.sh; then echo 'Backup unexpectedly passed with DB down' >&2; exit 1; fi
wait_healthy
bash scripts/smoke-test.sh "$base" "$APP_VERSION"
echo 'PASS incident 2: stopped DB returned 503, backup failed, recovery verified'

if MONGO_URI=mongodb://missing-db:27017/notedb docker compose up -d --no-build --wait --wait-timeout 35 app; then
  echo 'Bad MONGO_URI unexpectedly healthy' >&2; exit 1
fi
docker compose logs --no-color --tail 8 app
wait_healthy
bash scripts/smoke-test.sh "$base" "$APP_VERSION"
echo 'PASS incident 3: invalid MONGO_URI rejected and recovered'
