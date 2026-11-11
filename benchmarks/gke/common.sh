# Sourced by the GKE measurement scripts: waits that give up, so a cluster that goes away ends the run instead of hanging it.

wait_for_pods() {
  for _ in $(seq 150); do
    [ "$(kubectl -n demo get pods -l "$1" --no-headers 2>/dev/null | wc -l)" -eq "$2" ] && return
    sleep 2
  done
  echo "timed out waiting for $2 pods matching $1" >&2
  exit 1
}

rolled_out() {
  for deployment in "$@"; do
    kubectl -n demo rollout status "deploy/$deployment" --timeout=300s >/dev/null || exit 1
  done
}
