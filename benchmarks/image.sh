#!/usr/bin/env bash
# Reproduces the image-level numbers of the talk: size, rebuild time and new layers after a one-line edit of app.py,
# OS packages and known vulnerabilities (Trivy, run as a container) for deploy/bad and deploy/good.
# Needs podman (or CONTAINER=docker) and network access.
# Usage: benchmarks/image.sh
set -euo pipefail
cd "$(dirname "$0")/.."
C=${CONTAINER:-podman}
TRIVY_IMAGE=ghcr.io/aquasecurity/trivy:0.76.2
IMAGES="bad good"

work=$(mktemp -d)
trap 'rm -rf "$work"; for img in $IMAGES; do $C rmi -f "timing-$img" >/dev/null 2>&1 || true; done' EXIT
mkdir -p "$work/context" "$work/scan" "$work/trivy-cache"
cp -R app deploy .dockerignore "$work/context/"

now() { python3 -c 'import time; print(time.time())'; }
since() { python3 -c "import time; print(f'{time.time() - $1:.1f}')"; }

echo "## 1. Tamaño de la imagen"
for img in $IMAGES; do
  $C build -q -t "$img" -f "deploy/$img/Dockerfile" . >/dev/null
  echo "$img: $($C image inspect "localhost/$img" --format '{{.Size}}' | awk '{printf "%.0f MB", $1/1e6}')"
done

echo; echo "## 2. Tras cambiar una línea de app.py (caché caliente, 3 intentos): tiempo de reconstrucción y capas nuevas"
for img in $IMAGES; do
  $C build -q -t "timing-$img" -f "deploy/$img/Dockerfile" "$work/context" >/dev/null
  times=""
  for _ in 1 2 3; do
    echo "# $(now)" >> "$work/context/app/app.py"
    started=$(now)
    $C build -q -t "timing-$img" -f "deploy/$img/Dockerfile" "$work/context" >/dev/null
    times="$times $(since "$started")s"
  done
  new_layers=$($C history --format json "localhost/timing-$img" | python3 -I -c "
import json, sys
from datetime import datetime
rebuilt_at = float(sys.argv[1]) - 1
sizes = [row['size'] for row in json.load(sys.stdin) if datetime.fromisoformat(row['created']).timestamp() >= rebuilt_at]
print(f'{sum(sizes) / 1e6:.2f} MB')" "$started")
  echo "$img:$times | capas que hay que volver a subir y descargar: $new_layers"
  cp app/app.py "$work/context/app/app.py"
done

echo; echo "## 3. Paquetes del sistema (dpkg)"
for img in $IMAGES; do
  echo "$img: $($C run --rm --entrypoint sh "localhost/$img" -c "dpkg-query -f '.\n' -W | wc -l" | tr -d ' ') paquetes"
done

echo; echo "## 4. Vulnerabilidades conocidas (Trivy, solo paquetes del SO y de Python; cambian cada día)"
trivy() { $C run --rm -v "$work/scan:/in:ro" -v "$work/trivy-cache:/root/.cache" "$TRIVY_IMAGE" "$@"; }
for img in $IMAGES; do $C save -o "$work/scan/$img.tar" "localhost/$img"; done
for img in $IMAGES; do
  trivy image --quiet --input "/in/$img.tar" --scanners vuln --format json > "$work/$img.json"
  python3 -I - "$img" "$work/$img.json" <<'PY'
import collections, json, sys
name, path = sys.argv[1:]
vulns = [v for r in json.load(open(path)).get("Results", []) for v in r.get("Vulnerabilities") or []]
by_severity = collections.Counter(v["Severity"] for v in vulns)
counts = " ".join(f"{s}={by_severity[s]}" for s in ("CRITICAL", "HIGH", "MEDIUM", "LOW"))
fixable = sum(1 for v in vulns if v.get("FixedVersion"))
print(f"{name}: {counts} total={len(vulns)} con_fix={fixable}")
PY
done
trivy version | grep -E "^(Version|Vulnerability DB|  (Version|UpdatedAt|DownloadedAt))"
