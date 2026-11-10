#!/usr/bin/env bash
# Reproduces the deploy-level numbers of the talk: same app.py, two ways of packaging and running it.
# Needs podman (or CONTAINER=docker) and k6. Every container is limited to 1 CPU, like the pod.
set -euo pipefail
cd "$(dirname "$0")/.."
C=${CONTAINER:-podman}
RATES=${RATES:-"100 300"}

$C network create shop >/dev/null 2>&1 || true
$C build -q -t bad -f deploy/bad/Dockerfile . >/dev/null
$C build -q -t good -f deploy/good/Dockerfile . >/dev/null
$C build -q -t good-nobc --build-arg UV_COMPILE_BYTECODE=0 -f deploy/good/Dockerfile . >/dev/null
$C build -q -t payments payments >/dev/null
printf 'FROM localhost/bad\nCMD ["./start.sh"]\n' | $C build -q -t bad-jsoncmd - >/dev/null
DATABASE_URL=postgresql://shop:shop@postgres/shop
$C rm -f -t0 payments postgres >/dev/null 2>&1 || true
$C run -d --name postgres --network shop -e POSTGRES_USER=shop -e POSTGRES_PASSWORD=shop -e POSTGRES_DB=shop \
  -v "$PWD/db/schema.sql:/docker-entrypoint-initdb.d/schema.sql:ro" docker.io/library/postgres:17 \
  -c max_connections=500 >/dev/null
until $C exec postgres pg_isready -q -h 127.0.0.1 -U shop -d shop; do sleep 0.5; done
$C run -d --name payments --network shop --cpus 2 -e DATABASE_URL=$DATABASE_URL payments >/dev/null

now() { python3 -c 'import time; print(time.time())'; }
since() { python3 -c "import time; print(f'{time.time() - $1:.2f}')"; }
start() {
  $C rm -f -t0 shop >/dev/null 2>&1 || true
  $C run -d --name shop --network shop --cpus 1 --memory "$2" -p 8000:8000 \
    -e PAYMENTS_URL=http://payments:8000/charge -e DATABASE_URL=$DATABASE_URL -e SHOP_NAME=bad "$1" >/dev/null
}
wait_ready() { until curl -sf -m 1 localhost:8000/health >/dev/null; do sleep 0.05; done; }
oom_kills() { $C exec shop sh -c 'grep oom_kill /sys/fs/cgroup/memory.events | head -1 | cut -d" " -f2'; }

echo "## 1. Imagen y arranque (contenedor creado -> primer 200, 3 intentos)"
for img in bad good good-nobc; do
  size=$($C image inspect "localhost/$img" --format '{{.Size}}' | awk '{printf "%.0f MB", $1/1e6}')
  times=""
  for _ in 1 2 3; do t=$(now); start "$img" 2g; wait_ready; times="$times $(since "$t")s"; done
  echo "$img: $size |$times"
done

echo; echo "## 4. Núcleos y memoria (1 CPU, 1 GiB)"
start bad 1g; wait_ready
echo "os.cpu_count() dentro del contenedor: $($C exec shop python -c 'import os; print(os.cpu_count())')"
echo "procesos gunicorn: $($C exec shop sh -c 'ps -eo args | grep -c "[g]unicorn"')"
sleep 60
echo "procesos muertos por OOM en 60 s sin tráfico: $(oom_kills)"

echo; echo "## 4. Misma carga (constant-arrival-rate, 60 s)"
for rate in $RATES; do
  for cfg in "bad 1g" "bad 2g" "good 1g"; do
    set -- $cfg
    start "$1" "$2"; wait_ready; sleep 8
    result=$(TARGETS="$1=http://127.0.0.1:8000" RATE=$rate DURATION=60s k6 run -q k6/test.js 2>&1 \
      | grep -E "http_req_duration\.|http_req_failed|dropped_iterations" | awk '{$1=$1}1' | tr '\n' ' ')
    echo "$1 ($2) @ $rate rps: $result| oom_kill=$(oom_kills)"
  done
done

echo; echo "## 2. Apagado (stop con 30 s de gracia)"
for img in bad bad-jsoncmd good; do
  start "$img" 2g; wait_ready
  pid1=$($C exec shop cat /proc/1/cmdline | tr '\0' ' ')
  t=$(now); $C stop -t 30 shop >/dev/null
  echo "$img: $(since "$t")s, exit $($C inspect shop --format '{{.State.ExitCode}}'), PID 1 = $pid1"
done

$C rm -f -t0 shop payments postgres >/dev/null
