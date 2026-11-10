#!/bin/sh
# Seconds from pod creation to its first HTTP 200, for each side. Run on a fresh node to include the image pull.
set -eu
for side in bad good; do
  replicas=$(kubectl -n demo get deploy/$side -o jsonpath='{.spec.replicas}')
  kubectl -n demo scale deploy/$side --replicas=$((replicas + 1)) >/dev/null
  sleep 2
  pod=$(kubectl -n demo get pods -l app=$side --sort-by=.metadata.creationTimestamp -o name | tail -1)
  until ip=$(kubectl -n demo get $pod -o jsonpath='{.status.podIP}') && [ -n "$ip" ]; do sleep 0.5; done
  created=$(kubectl -n demo get $pod -o jsonpath='{.metadata.creationTimestamp}')
  kubectl -n demo exec deploy/payments -- python -c "
import time, urllib.request
from datetime import datetime
created = datetime.fromisoformat('$created').timestamp()
while True:
    try:
        urllib.request.urlopen('http://$ip:8000/health', timeout=1)
        break
    except Exception:
        time.sleep(0.2)
print(f'$side: {time.time() - created:.1f}s desde que se creó el pod hasta el primer 200')
"
  kubectl -n demo scale deploy/$side --replicas=$replicas >/dev/null
done
