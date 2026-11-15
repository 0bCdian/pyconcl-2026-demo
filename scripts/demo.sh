#!/bin/bash
# The live demos, bad against good with `time`: rebuild after a one-line change, startup until the first 200, and stop.
# Needs `make local` running (its network and PostgreSQL). Usage: demo.sh build | start | stop | size
set -eu
cd "$(dirname "$0")/.."
ENV="-e PAYMENTS_URL=http://payments:8000/charge -e DATABASE_URL=postgresql://shop:shop@postgres/shop -e LOG_LEVEL=INFO"

case ${1:?build|start|stop|size} in
build)
  echo "# demo $(date +%s)" >> app/app.py
  for version in bad good; do
    echo "== $version"
    time podman build --pull=never -q -t pycon-$version -f deploy/$version/Dockerfile . >/dev/null
  done
  sed -i '' '$d' app/app.py
  ;;
start)
  # Only the demo containers use the database: with make local's replicas, A's 17 workers exhaust max_connections.
  podman stop -t0 bad-1 bad-2 good-1 good-2 arena >/dev/null 2>&1 || true
  for version in bad good; do
    podman rm -f -t0 demo-$version >/dev/null 2>&1 || true
    echo "== $version"
    time {
      podman run -d --name demo-$version --network pycon --cpus 1 --memory 2g $ENV -e SHOP_NAME=$version pycon-$version >/dev/null
      until podman exec demo-$version python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" 2>/dev/null; do sleep 0.2; done
    }
    echo "procesos: $(podman top demo-$version args | grep -c '[g]unicorn\|[u]vicorn')"
  done
  ;;
stop)
  for version in bad good; do
    echo "== $version"
    time podman stop demo-$version >/dev/null
    echo "exit code: $(podman inspect demo-$version --format '{{.State.ExitCode}}')"
  done
  ;;
size)
  podman images --format '{{.Repository}} {{.Size}}' | grep -E 'pycon-(bad|good) '
  ;;
esac
