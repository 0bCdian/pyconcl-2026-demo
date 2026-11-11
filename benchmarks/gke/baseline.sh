#!/bin/bash
# Baseline rows ("ninguna" = bad, "todas" = good): memory at 200 rps, 550 rps peak, charges per deploy. Usage: baseline.sh [runs=3]
cd "$(dirname "$0")/../.."
. benchmarks/gke/common.sh
for run in $(seq 1 "${1:-3}"); do
  echo "######## baseline run $run $(date +%T)"
  make load RATE=200 DURATION=90s >/dev/null || exit 1; sleep 80
  kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090 >/dev/null 2>&1 & PF=$!; sleep 3
  benchmarks/gke/resources.sh; kill $PF
  kubectl -n demo wait --for=condition=complete job/k6 --timeout=120s >/dev/null

  make load RATE=550 DURATION=3m >/dev/null || exit 1; sleep 60
  benchmarks/gke/watch.sh 7
  kubectl -n demo get pods -l 'app in (bad,good)' --no-headers | awk '{print "   ", $1, $2, $3, "restarts=" $4}'
  kubectl -n demo wait --for=condition=complete job/k6 --timeout=300s >/dev/null
  kubectl -n demo delete job k6 >/dev/null

  sleep 15
  benchmarks/gke/charges.sh rollout || exit 1
  sleep 30
done
echo "######## done $(date +%T)"
