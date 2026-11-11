#!/usr/bin/env bash
set -Eeuo pipefail
base=${1:-http://127.0.0.1:3000}
expected=${2:-}
health=$(curl --fail --silent --show-error --max-time 10 "$base/health")
python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["status"] == "OK" and d["database"] == "up"; assert not sys.argv[2] or d["version"] == sys.argv[2]; print("Healthy version:", d["version"])' "$health" "$expected"
curl --fail --silent --show-error --max-time 10 "$base/notes" | python3 -c 'import json,sys; assert isinstance(json.load(sys.stdin),list); print("Notes API: OK")'
curl --fail --silent --show-error --max-time 10 "$base/" -o /dev/null
echo 'Homepage: OK'
