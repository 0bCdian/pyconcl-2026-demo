#!/bin/bash
# "Qué práctica pesa más" on GKE: bad image with one good practice at a time; memory at 200 rps, 550 rps peak, charges per deploy.
# Usage: ablation.sh [workers1 cpucount1 exec debug]   (run build.sh first; bad and good must be deployed with `make deploy`)
cd "$(dirname "$0")/../.."
REPO=$(tofu -chdir=infra output -raw registry)
settle() {
  for d in bad good; do kubectl -n demo rollout status deploy/$d --timeout=300s >/dev/null; done
  until [ "$(kubectl -n demo get pods -l 'app in (bad,good)' --no-headers | wc -l)" -eq 4 ]; do sleep 2; done
}

variants=${*:-workers1 cpucount1 exec debug}
for variant in $variants; do
  echo "######## $variant"
  case $variant in
  workers1|exec) kubectl -n demo set image deploy/bad bad=$REPO/bad-$variant:latest >/dev/null ;;
  cpucount1) kubectl -n demo set env deploy/bad PYTHON_CPU_COUNT=1 >/dev/null ;;
  debug) kubectl -n demo set env deploy/bad LOG_LEVEL=DEBUG >/dev/null ;;
  esac
  settle; sleep 20
  kubectl -n demo exec deploy/bad -- sh -c 'echo "   procesos: $(ls /proc | grep -c "^[0-9]") pid1=$(tr "\0" " " < /proc/1/cmdline)"'

  make load RATE=200 DURATION=90s >/dev/null; sleep 80
  kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090 >/dev/null 2>&1 & PF=$!; sleep 3
  benchmarks/gke/resources.sh | grep -E 'memoria/pod|cpu/pod|throttling'; kill $PF
  kubectl -n demo wait --for=condition=complete job/k6 --timeout=120s >/dev/null

  make load RATE=550 DURATION=3m >/dev/null; sleep 60
  benchmarks/gke/watch.sh 7 | grep -vE 'harness|offered|cpu/pod'
  kubectl -n demo get pods -l app=bad --no-headers | awk '{print "   ", $1, $2, $3, "restarts=" $4}'
  kubectl -n demo wait --for=condition=complete job/k6 --timeout=300s >/dev/null
  kubectl -n demo delete job k6 >/dev/null

  sleep 15
  benchmarks/gke/charges.sh rollout

  case $variant in
  cpucount1) kubectl -n demo set env deploy/bad PYTHON_CPU_COUNT- >/dev/null ;;
  debug) kubectl -n demo set env deploy/bad LOG_LEVEL- >/dev/null ;;
  esac
  make deploy >/dev/null; settle
done
