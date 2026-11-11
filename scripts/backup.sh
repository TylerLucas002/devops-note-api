#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
cd "$(dirname "$0")/.."
BACKUP_DIR=${BACKUP_DIR:-/home/ubuntu/backups}
DB_NAME=${DB_NAME:-notedb}
[[ "$DB_NAME" =~ ^[a-zA-Z0-9_-]+$ ]] || { echo 'Invalid DB_NAME' >&2; exit 1; }
mkdir -p "$BACKUP_DIR"
archive=$(mktemp "$BACKUP_DIR/db_backup_$(date -u +%Y-%m-%d_%H-%M-%S)_XXXXXX.archive.gz")
trap 'rm -f "$archive" "$archive.sha256"' ERR
# Stream directly out of the container; do not leave stale /dump files behind.
docker compose exec -T db mongodump --db "$DB_NAME" --archive --gzip > "$archive"
test -s "$archive"
(cd "$BACKUP_DIR" && sha256sum "$(basename "$archive")" > "$(basename "$archive").sha256")
echo "Backup verified: $archive"
