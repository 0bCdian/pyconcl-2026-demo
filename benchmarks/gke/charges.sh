#!/bin/bash
# "Por deploy" column: per version, charges in the payments ledger vs orders and client errors seen by the arena, around an event.
# Usage: charges.sh none|rollout [orders per second per side, default 200]
cd "$(dirname "$0")/../.."
. benchmarks/gke/common.sh
EVENT=${1:?none|rollout} RATE=${2:-200}
TOKEN=${TOKEN:-$(kubectl -n demo logs deploy/arena | grep -m1 -o 'token=[^ ]*' | cut -d= -f2)}
kubectl -n demo port-forward svc/arena 8081:80 >/dev/null 2>&1 & PF1=$!
kubectl -n demo port-forward svc/payments 8082:80 >/dev/null 2>&1 & PF2=$!
trap 'kill $PF1 $PF2' EXIT
sleep 3
admin() { curl -s -X POST localhost:8081/admin -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d "$1" >/dev/null; }

START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
admin "{\"reset\": true, \"autoplay\": $RATE}"
sleep 30
echo "== $EVENT at $(date +%T), $RATE orders/s per side"
case $EVENT in
none) sleep 60 ;;
rollout)
  make rollout >/dev/null || exit 1
  for side in bad good; do
    rolled_out $side
    wait_for_pods app=$side 2
  done
  sleep 15 ;;
esac
admin '{"autoplay": 0}'
sleep 20
RECONCILIATION=$(curl -s --get localhost:8082/reconciliation --data-urlencode "since=$START") \
STATS=$(curl -s localhost:8081/stats) python3 -c "
import json, os
ledger = json.loads(os.environ['RECONCILIATION'])
stats = json.loads(os.environ['STATS'])
for version, side in (('bad', 'A'), ('good', 'B')):
    r = ledger[version]
    print(f\"   {version}: cobros={r['charges']} ordenes={r['orders']} error_al_cliente={stats[side]['lost']} cobradas_sin_orden={r['charged_without_order']}\")
"
