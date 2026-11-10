#!/bin/bash
# Per-version offered/ok/err/p95/CPU/throttling every 30 s during a k6 run: the 550 rps peak (7 samples) and the stress knee (22 samples).
# Usage: watch.sh [samples=22]
kubectl -n monitoring port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090 >/dev/null 2>&1 & PF=$!
trap 'kill $PF' EXIT
sleep 3
q() {
  curl -s --get localhost:9090/api/v1/query --data-urlencode "query=$1" |
    python3 -c "import json,sys; r=json.load(sys.stdin)['data']['result']; print(' '.join(f\"{list(x['metric'].values())[0] if x['metric'] else 'all'}={float(x['value'][1]):.${2:-0}f}\" for x in sorted(r, key=lambda x: str(x['metric']))))"
}
S='namespace="demo", container=~"bad|good"'
for i in $(seq 1 "${1:-22}"); do
  echo "$(date +%T) offered=$(q 'sum by (scenario) (rate(k6_http_reqs_total{scenario=~"bad|good"}[30s])) + sum by (scenario) (rate(k6_dropped_iterations_total{scenario=~"bad|good"}[30s]))')"
  echo "   ok/s      $(q 'sum by (scenario) (rate(k6_http_reqs_total{scenario=~"bad|good", expected_response="true"}[30s]))')"
  echo "   err/s     $(q 'sum by (scenario) (rate(k6_http_reqs_total{scenario=~"bad|good", expected_response="false"}[30s]))')"
  echo "   dropped/s $(q 'sum by (scenario) (rate(k6_dropped_iterations_total{scenario=~"bad|good"}[30s]))')"
  echo "   p95 ms    $(q 'max by (scenario) (k6_http_req_duration_p95{scenario=~"bad|good"}) * 1000')"
  echo "   cpu/pod   $(q "avg by (container) (rate(container_cpu_usage_seconds_total{$S}[1m]))" 2)"
  echo "   throttle  $(q "sum by (container) (rate(container_cpu_cfs_throttled_periods_total{$S}[1m])) / sum by (container) (rate(container_cpu_cfs_periods_total{$S}[1m]))" 2)"
  echo "   harness   $(q 'sum by (container) (rate(container_cpu_usage_seconds_total{namespace="demo", container=~"payments|k6"}[1m]))' 2) tools_node=$(q 'sum(rate(container_cpu_usage_seconds_total{id="/", instance=~".*tools.*"}[1m]))' 2)"
  sleep 30
done
