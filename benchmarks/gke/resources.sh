#!/bin/bash
# Per-version memory, CPU, throttling, restarts and OOM snapshot ("Memoria por pod" column). Needs Prometheus on localhost:9090.
# Usage: resources.sh
q() {
  curl -s --get localhost:9090/api/v1/query --data-urlencode "query=$2" |
    python3 -c "import json,sys; r=json.load(sys.stdin)['data']['result']; print(f'  {\"$1\":<22}', '  '.join(f\"{x['metric'].get('container', x['metric'].get('deployment','?'))}={float(x['value'][1]):.3f}\" for x in sorted(r, key=lambda x: str(x['metric']))))"
}
S='namespace="demo", container=~"bad|good"'
echo "$(date +%T)"
q "memoria/pod MiB"   "avg by (container) (container_memory_working_set_bytes{$S}) / 2^20"
q "memoria max MiB"   "max by (container) (container_memory_working_set_bytes{$S}) / 2^20"
q "limite MiB"        "avg by (container) (kube_pod_container_resource_limits{resource=\"memory\", $S}) / 2^20"
q "cpu/pod cores"     "avg by (container) (rate(container_cpu_usage_seconds_total{$S}[1m]))"
q "throttling"        "sum by (container) (rate(container_cpu_cfs_throttled_periods_total{$S}[1m])) / sum by (container) (rate(container_cpu_cfs_periods_total{$S}[1m]))"
q "listos"            "kube_deployment_status_replicas_ready{namespace=\"demo\", deployment=~\"bad|good\"}"
q "reinicios"         "sum by (container) (kube_pod_container_status_restarts_total{$S})"
q "oom events 5m"     "sum by (container) (increase(container_oom_events_total{$S}[5m]))"
q "payments cpu"      "sum by (container) (rate(container_cpu_usage_seconds_total{namespace=\"demo\", container=\"payments\"}[1m]))"
