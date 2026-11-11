#!/usr/bin/env bash
# Exercise deploy.sh against real good/bad images in an isolated checkout/volume.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
[[ ${COMPOSE_PROJECT_NAME:-} == note-check-* ]] || { echo 'Use a note-check-* project' >&2; exit 1; }
source_dir=$PWD
mkdir -p work
checkout=$(mktemp -d "$PWD/work/rollout-XXXXXX")
git clone --quiet --no-hardlinks "$source_dir" "$checkout"
cd "$checkout"
export APP_CONTAINER_NAME="$COMPOSE_PROJECT_NAME-app" DB_CONTAINER_NAME="$COMPOSE_PROJECT_NAME-db"
export APP_PORT=${APP_PORT:-13001} APP_BIND_ADDRESS=127.0.0.1 MONGO_URI=mongodb://db:27017/notedb
export BACKUP_DIR="$checkout/work/backups"
mkdir -p work
trap 'docker compose logs --no-color --tail 15 app || true; docker compose down -v --remove-orphans' EXIT
good=$(git rev-parse HEAD)
bash scripts/deploy.sh "$good"
base="http://127.0.0.1:$APP_PORT"
note=$(curl -fsS "$base/notes" -H 'Content-Type: application/json' -d '{"title":"rollback-proof","content":"must survive failed deployment"}')
id=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["_id"])' "$note")
# A real process starts but always fails readiness.
cat > server.js <<'JS'
require('http').createServer((req,res) => {
  res.writeHead(503, {'Content-Type':'application/json'});
  res.end(JSON.stringify({status:'INJECTED_FAILURE'}));
}).listen(3000);
JS
git add server.js
git -c user.name='CI rollback drill' -c user.email='ci@example.invalid' commit -qm 'Inject isolated readiness failure'
bad=$(git rev-parse HEAD)
if bash scripts/deploy.sh "$bad" > work/failed-deployment.log 2>&1; then
  echo 'Bad deployment unexpectedly succeeded' >&2; exit 1
fi
cat work/failed-deployment.log
grep -q 'unhealthy' work/failed-deployment.log
grep -q 'Previous image restored' work/failed-deployment.log
if grep -q 'ROLLBACK FAILED' work/failed-deployment.log; then exit 1; fi
bash scripts/smoke-test.sh "$base" "$good"
curl -fsS "$base/notes" | python3 -c 'import json,sys; assert any(n["_id"]==sys.argv[1] and n["content"]=="must survive failed deployment" for n in json.load(sys.stdin))' "$id"
python3 - "$good" <<'PY'
from pathlib import Path
import sys
assert 'APP_VERSION='+sys.argv[1] in Path('.env').read_text()
assert 'APP_IMAGE=devops-note-api:rollback' in Path('.env').read_text()
PY
echo 'PASS rollback: bad readiness rejected; previous version, data and persisted configuration recovered'
