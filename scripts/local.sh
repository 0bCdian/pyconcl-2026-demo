#!/bin/sh
# Local preview of the arena in Podman: 2 replicas per version with the same limits, a load balancer per version.
# It has no readiness gating, endpoint removal or grace periods, so only GKE shows the deployment differences.
# Usage: local.sh up | load | down
set -eu
cd "$(dirname "$0")/.."
NET=pycon
CADDY=docker.io/library/caddy:2.10.2
K6=docker.io/grafana/k6:2.3.0
DATABASE_URL=postgresql://shop:shop@postgres/shop
SHOP_ENV="-e PAYMENTS_URL=http://payments:8000/charge -e DATABASE_URL=$DATABASE_URL -e LOG_LEVEL=INFO"

run() {
  name=$1
  shift
  podman rm -f "$name" >/dev/null 2>&1 || true
  podman run -d --name "$name" --network $NET "$@" >/dev/null
}

case ${1:-up} in
up)
  podman build -q -t pycon-bad -f deploy/bad/Dockerfile . >/dev/null
  podman build -q -t pycon-good -f deploy/good/Dockerfile . >/dev/null
  podman build -q -t pycon-payments payments >/dev/null
  podman build -q -t pycon-arena arena >/dev/null
  podman network exists $NET || podman network create $NET >/dev/null

  run postgres -e POSTGRES_USER=shop -e POSTGRES_PASSWORD=shop -e POSTGRES_DB=shop \
    -v "$PWD/db/schema.sql:/docker-entrypoint-initdb.d/schema.sql:ro" docker.io/library/postgres:17 -c max_connections=500
  until podman exec postgres pg_isready -q -h 127.0.0.1 -U shop -d shop; do sleep 0.5; done
  run payments -e LATENCY_MS=150 -e DATABASE_URL=$DATABASE_URL pycon-payments
  for i in 1 2; do
    run bad-$i --cpus 1 --memory 2g $SHOP_ENV -e SHOP_NAME=bad pycon-bad
    run good-$i --cpus 1 --memory 2g $SHOP_ENV -e SHOP_NAME=good pycon-good
  done
  run lb-bad $CADDY caddy reverse-proxy --from :80 --to bad-1:8000 --to bad-2:8000
  run lb-good $CADDY caddy reverse-proxy --from :80 --to good-1:8000 --to good-2:8000

  token=${ADMIN_TOKEN:-$(openssl rand -hex 12)}
  public_url=${PUBLIC_URL:-http://$(ipconfig getifaddr en0 || echo localhost):8080}
  run arena -p 8080:8000 -e A_URL=http://lb-bad -e B_URL=http://lb-good -e PAYMENTS_URL=http://payments:8000 \
    -e PUBLIC_URL="$public_url" -e ADMIN_TOKEN="$token" pycon-arena
  echo "Pantalla: http://localhost:8080/screen?token=$token"
  echo "Celular:  $public_url"
  ;;
load)
  podman run --rm --network $NET -v "$PWD/k6:/scripts:ro" \
    -e RATE="${RATE:-300}" -e DURATION="${DURATION:-10m}" -e TARGETS=bad=http://lb-bad,good=http://lb-good \
    $K6 run --quiet /scripts/test.js
  ;;
down)
  podman rm -f arena lb-bad lb-good bad-1 bad-2 good-1 good-2 payments postgres >/dev/null 2>&1 || true
  ;;
esac
