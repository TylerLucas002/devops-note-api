#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
version=${1:-$(git rev-parse HEAD)}
[[ "$version" =~ ^[0-9a-f]{40}$ ]] || { echo 'Expected full commit SHA' >&2; exit 1; }
[[ $(git rev-parse HEAD) == "$version" ]] || { echo 'Checkout does not match requested version' >&2; exit 1; }
# Prevent overlapping deployments even when invoked outside GitHub Actions.
exec 9>/tmp/devops-note-api-deploy.lock
flock -n 9 || { echo 'Another deployment is running' >&2; exit 1; }
old_container=$(docker compose ps -q app)
old_image=''
old_version=''
if [[ -n "$old_container" ]]; then
  old_image=$(docker inspect --format '{{.Image}}' "$old_container")
  old_version=$(docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$old_container" | sed -n 's/^APP_VERSION=//p')
fi
export APP_IMAGE="devops-note-api:$version" APP_VERSION="$version"
# Build before touching the running stack. Build failure leaves the old app serving.
docker compose build app
if [[ -n $(docker compose ps -q db) ]]; then bash scripts/backup.sh; fi
persist_selection() {
python3 - "$APP_IMAGE" "$APP_VERSION" <<'PY'
import os,pathlib,sys,tempfile
p=pathlib.Path('.env')
lines=p.read_text().splitlines() if p.exists() else []
lines=[x for x in lines if not x.startswith(('APP_IMAGE=', 'APP_VERSION='))]
lines += ['APP_IMAGE='+sys.argv[1], 'APP_VERSION='+sys.argv[2]]
fd,tmp=tempfile.mkstemp(prefix='.env-',dir='.')
with os.fdopen(fd,'w') as f: f.write('\n'.join(lines)+'\n')
os.replace(tmp,p)
PY
}
rollback() {
  trap - ERR
  echo 'Deployment failed; restoring previous application image.' >&2
  if [[ -n "$old_image" ]]; then
    docker tag "$old_image" devops-note-api:rollback
    export APP_IMAGE=devops-note-api:rollback APP_VERSION="${old_version:-previous}"
    if docker compose up -d --no-build --wait --wait-timeout 120 app; then
      persist_selection
      echo 'Previous image restored; deployment remains failed.' >&2
    else
      echo 'ROLLBACK FAILED: inspect docker compose logs immediately.' >&2
    fi
  else
    echo 'No previous image exists; inspect first-deployment logs.' >&2
  fi
  exit 1
}
trap rollback ERR
docker compose up -d --no-build --wait --wait-timeout 120
bash scripts/smoke-test.sh "http://127.0.0.1:${APP_PORT:-3000}" "$version"
# Persist the selected image for later compose/restore commands without exposing secrets.
persist_selection
trap - ERR
echo "Deployed and verified: $version"
