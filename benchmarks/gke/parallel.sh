#!/bin/bash
# "Cuántos procesos por pod": same 2 CPUs per version, workers per pod vs pods, ramp 100 to 1000 rps against good in the same run.
# Usage: parallel.sh [cgroup-1cpu cgroup-2cpu workers1-2cpu cgroup1-2cpu blas1]   (run build.sh first)
cd "$(dirname "$0")/../.."
. benchmarks/gke/common.sh
REPO=$(tofu -chdir=infra output -raw registry)
settle() {
  rolled_out bad good
  wait_for_pods 'app in (bad,good)' $(( $(kubectl -n demo get deploy/bad -o jsonpath='{.spec.replicas}') + 2 ))
}
variants=${*:-cgroup-1cpu cgroup-2cpu workers1-2cpu cgroup1-2cpu blas1}
for variant in $variants; do
  echo "######## $variant"
  case $variant in
  cgroup-1cpu)
    kubectl -n demo set image deploy/bad bad=$REPO/bad-cgroup:latest >/dev/null
    kubectl -n demo set env deploy/bad WEB_CONCURRENCY=3 >/dev/null ;;
  cgroup-2cpu|cgroup1-2cpu|workers1-2cpu)
    image=$REPO/bad-cgroup:latest
    [ $variant = workers1-2cpu ] && image=$REPO/bad-workers1:latest
    kubectl -n demo set image deploy/bad bad=$image >/dev/null
    [ $variant = cgroup-2cpu ] && kubectl -n demo set env deploy/bad WEB_CONCURRENCY=5 >/dev/null
    kubectl -n demo set resources deploy/bad --requests=cpu=2,memory=4Gi --limits=cpu=2,memory=4Gi >/dev/null
    kubectl -n demo scale deploy/bad --replicas=1 >/dev/null ;;
  blas1) kubectl -n demo set env deploy/bad OPENBLAS_NUM_THREADS=1 >/dev/null ;;
  esac
  settle; sleep 20
  kubectl -n demo exec deploy/bad -- sh -c 'echo "   cpu.max=$(cat /sys/fs/cgroup/cpu.max) procesos=$(ls -d /proc/[0-9]* | wc -l) hilos=$(ls -d /proc/[0-9]*/task/* | wc -l)"'

  make load RATE=200 DURATION=100s >/dev/null || exit 1; sleep 90
  kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090 >/dev/null 2>&1 & PF=$!; sleep 3
  benchmarks/gke/resources.sh | grep -E 'memoria/pod|cpu/pod'
  curl -s --get localhost:9090/api/v1/query --data-urlencode 'query=sum by (container) (container_memory_working_set_bytes{namespace="demo", container=~"bad|good"}) / 2^20' |
    python3 -c "import json,sys; print('  memoria total MiB     ', '  '.join(f\"{x['metric']['container']}={float(x['value'][1]):.0f}\" for x in json.load(sys.stdin)['data']['result']))"
  kill $PF
  kubectl -n demo wait --for=condition=complete job/k6 --timeout=120s >/dev/null

  if [ $variant = blas1 ]; then
    make load RATE=550 DURATION=3m >/dev/null || exit 1; START=$(date +%s); sleep 190
  else
    make load RATE=100 RAMP_TO=1000 DURATION=8m >/dev/null || exit 1; START=$(date +%s); sleep 490
  fi
  kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090 >/dev/null 2>&1 & PF=$!; sleep 3
  python3 benchmarks/gke/knee.py <(echo "$variant $START $(date +%s)"); kill $PF
  kubectl -n demo get pods -l app=bad --no-headers | awk '{print "   ", $1, $2, $3, "restarts=" $4}'
  kubectl -n demo delete job k6 >/dev/null 2>&1

  kubectl -n demo set env deploy/bad OPENBLAS_NUM_THREADS- WEB_CONCURRENCY- >/dev/null
  make deploy >/dev/null || exit 1; settle; sleep 30
done

