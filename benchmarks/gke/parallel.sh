#!/bin/bash
# "Cuántos procesos por pod": same 2 CPUs per version, workers per pod vs pods, ramp 100 to 1000 rps against good in the same run.
# Usage: parallel.sh [cgroup-1cpu cgroup-2cpu workers1-2cpu cgroup1-2cpu blas1]   (run build.sh first)
cd "$(dirname "$0")/../.."
REPO=$(tofu -chdir=infra output -raw registry)
WINDOWS=$(mktemp)
settle() {
  for d in bad good; do kubectl -n demo rollout status deploy/$d --timeout=300s >/dev/null; done
  want=$(( $(kubectl -n demo get deploy/bad -o jsonpath='{.spec.replicas}') + 2 ))
  until [ "$(kubectl -n demo get pods -l 'app in (bad,good)' --no-headers | wc -l)" -eq "$want" ]; do sleep 2; done
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

  make load RATE=200 DURATION=100s >/dev/null; sleep 90
  kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090 >/dev/null 2>&1 & PF=$!; sleep 3
  benchmarks/gke/resources.sh | grep -E 'memoria/pod|cpu/pod'
  curl -s --get localhost:9090/api/v1/query --data-urlencode 'query=sum by (container) (container_memory_working_set_bytes{namespace="demo", container=~"bad|good"}) / 2^20' |
    python3 -c "import json,sys; print('  memoria total MiB     ', '  '.join(f\"{x['metric']['container']}={float(x['value'][1]):.0f}\" for x in json.load(sys.stdin)['data']['result']))"
  kill $PF
  kubectl -n demo wait --for=condition=complete job/k6 --timeout=120s >/dev/null

  if [ $variant = blas1 ]; then
    make load RATE=550 DURATION=3m >/dev/null; START=$(date +%s); sleep 190
  else
    make load RATE=100 RAMP_TO=1000 DURATION=8m >/dev/null; START=$(date +%s); sleep 490
  fi
  echo "$variant $START $(date +%s)" >> "$WINDOWS"
  kubectl -n demo get pods -l app=bad --no-headers | awk '{print "   ", $1, $2, $3, "restarts=" $4}'
  kubectl -n demo delete job k6 >/dev/null 2>&1

  kubectl -n demo set env deploy/bad OPENBLAS_NUM_THREADS- WEB_CONCURRENCY- >/dev/null
  make deploy >/dev/null; settle; sleep 30
done

kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090 >/dev/null 2>&1 & PF=$!
trap 'kill $PF' EXIT
until curl -s localhost:9090/-/ready >/dev/null; do sleep 1; done
python3 benchmarks/gke/knee.py "$WINDOWS"
