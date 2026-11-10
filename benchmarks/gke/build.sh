#!/bin/bash
# Builds and pushes the single-practice variants of the bad image (bad-workers1, bad-exec, bad-slim, bad-cgroup) used by ablation.sh and parallel.sh.
# Usage: benchmarks/gke/build.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
out() { tofu -chdir=infra output -raw "$1"; }
gcloud builds submit . --config benchmarks/gke/variants/cloudbuild.yaml --project "$(out project_id)" --region "$(out region)" \
  --service-account "$(out build_service_account)" --gcs-source-staging-dir "$(out build_staging_dir)" \
  --substitutions _REPO="$(out registry)"
