#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
archive=${1:-}
if [[ ! -f "$archive" || ! -f "$archive.sha256" ]]; then
  echo 'Usage: CONFIRM_RESTORE=yes ./scripts/restore.sh /absolute/path/backup.archive.gz (checksum required)' >&2; exit 1
fi
[[ ${CONFIRM_RESTORE:-} == yes ]] || { echo 'Restore replaces existing collections. Set CONFIRM_RESTORE=yes after reviewing the target and backup.' >&2; exit 1; }
DB_NAME=${DB_NAME:-notedb}
[[ "$DB_NAME" =~ ^[a-zA-Z0-9_-]+$ ]] || { echo 'Invalid DB_NAME' >&2; exit 1; }
archive=$(realpath "$archive")
(cd "$(dirname "$archive")" && sha256sum -c "$(basename "$archive").sha256")
# Validate before stopping writers. Recovery always tries to restart the app.
docker compose exec -T db mongosh --quiet --eval 'quit(db.adminCommand("ping").ok ? 0 : 1)' >/dev/null
docker compose stop app
trap 'docker compose start app >&2 || true' EXIT
docker compose exec -T db mongorestore --archive --gzip --drop --stopOnError --nsInclude "$DB_NAME.*" < "$archive"
docker compose up -d --no-build --wait --wait-timeout 120 app
trap - EXIT
echo 'Restore completed; app and database are healthy.'
