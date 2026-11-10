#!/bin/bash
# Image size, startup to first 200 (3 tries), idle memory and shutdown time for each single-practice variant, in Podman.
# Usage: local-ablation.sh   (needs podman)
set -eu
cd "$(dirname "$0")/../.."
C=podman
$C build -q -t bad -f deploy/bad/Dockerfile . >/dev/null
$C build -q -t good -f deploy/good/Dockerfile . >/dev/null
$C build -q -t good-nobc --build-arg UV_COMPILE_BYTECODE=0 -f deploy/good/Dockerfile . >/dev/null
sed 's/^FROM python:3.13$/FROM python:3.13-slim/' deploy/bad/Dockerfile | $C build -q -t bad-slim -f - . >/dev/null
for variant in workers1 exec; do
  $C build -q -t bad-$variant --build-arg BASE=localhost/bad -f benchmarks/gke/variants/$variant.Dockerfile benchmarks/gke/variants >/dev/null
done
$C build -q -t payments payments >/dev/null
$C network create shop >/dev/null 2>&1 || true
DATABASE_URL=postgresql://shop:shop@postgres/shop
$C rm -f -t0 payments postgres >/dev/null 2>&1 || true
$C run -d --name postgres --network shop -e POSTGRES_USER=shop -e POSTGRES_PASSWORD=shop -e POSTGRES_DB=shop \
  -v "$PWD/db/schema.sql:/docker-entrypoint-initdb.d/schema.sql:ro" docker.io/library/postgres:17 -c max_connections=500 >/dev/null
until $C exec postgres pg_isready -q -h 127.0.0.1 -U shop -d shop; do sleep 0.5; done
$C run -d --name payments --network shop --cpus 2 -e DATABASE_URL=$DATABASE_URL payments >/dev/null

now() { python3 -c 'import time; print(time.time())'; }
since() { python3 -c "import time; print(f'{time.time() - $1:.1f}')"; }
start() {
  $C rm -f -t0 shop >/dev/null 2>&1 || true
  $C run -d --name shop --network shop --cpus 1 --memory 2g -p 8000:8000 -e PAYMENTS_URL=http://payments:8000/charge -e DATABASE_URL=$DATABASE_URL -e SHOP_NAME=bad "$@" >/dev/null
}
wait_ready() { until curl -sf -m 1 localhost:8000/health >/dev/null; do sleep 0.05; done; }

for img in bad bad-slim bad-workers1 bad-exec good good-nobc; do
  size=$($C image inspect "localhost/$img" --format '{{.Size}}' | awk '{printf "%.0f MB", $1/1e6}')
  times=""
  for _ in 1 2 3; do t=$(now); start "localhost/$img"; wait_ready; times="$times $(since "$t")s"; done
  sleep 5
  mem=$($C stats --no-stream --format '{{.MemUsage}}' shop | cut -d/ -f1)
  t=$(now); $C stop -t 30 shop >/dev/null
  stop="$(since "$t")s exit $($C inspect shop --format '{{.State.ExitCode}}')"
  echo "$img | $size | arranque$times | memoria en reposo $mem | apagado $stop"
done
$C rm -f -t0 shop payments postgres >/dev/null
