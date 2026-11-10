#!/usr/bin/env bash
# Code-level lessons, run on the host with one uvicorn worker each. Needs uv and k6.
set -euo pipefail
cd "$(dirname "$0")"
UV="uv run -q --project ../../app --with requests"
out=$(mktemp -d)

serve() { $UV uvicorn "$@" --port 8100 >"$out/server.log" 2>&1 & }
ready() { until curl -sf -o /dev/null -m 1 "localhost:8100$1"; do sleep 0.2; done; }
stop() { pkill -f "uvicorn .*--port 8100" || true; while curl -s -o /dev/null -m 1 localhost:8100; do sleep 0.2; done; }

$UV uvicorn slow_service:app --port 9000 --workers 4 --no-access-log >/dev/null 2>&1 &
trap 'stop; pkill -f "uvicorn .*--port 9000" || true' EXIT
until curl -s -o /dev/null -X POST localhost:9000/charge; do sleep 0.2; done

echo "## async def / def (POST /orders, servicio externo de ~150 ms, tasa constante 60 s)"
for case in "async-blocking 100 40" "def 200 40" "def 400 40" "def 400 200" "async 400 40"; do
  set -- $case
  ENDPOINT=$1 THREADS=$3 serve async_vs_def:app --no-access-log; ready /docs
  echo -n "$1 (threadpool $3) @ $2 rps: "
  URL=http://127.0.0.1:8100/orders RATE=$2 k6 run -q orders.js 2>&1 \
    | grep -E "http_req_duration\.|http_req_failed|dropped_iterations" | awk '{$1=$1}1' | tr '\n' ' '; echo
  stop
done

echo; echo "## Costo de logear (GET /products, 30 usuarios concurrentes, 15 s)"
for mode in none eager-debug payload access lazy; do
  flags=--no-access-log; m=$mode
  [ "$mode" = access ] && { flags=--access-log; m=none; }
  LOG_MODE=$m serve logging_cost:app --log-level info $flags; ready /products
  rps=$(URL=http://127.0.0.1:8100/products k6 run -q products.js 2>&1 | awk '/http_reqs/{print $3}')
  stop
  echo "$mode: $rps | log escrito: $(du -h "$out/server.log" | cut -f1)"
done
