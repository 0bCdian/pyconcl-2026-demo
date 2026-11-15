# Working on this repo

Demo and deck for the PyCon Chile 2026 talk "Misma app, dos resultados distintos". `README.md` explains how to run it and reproduce each number.

## Rules

- Change Google Cloud only through OpenTofu (`infra/`). Save the plan with `-out`, review it, and apply that file. Never `-auto-approve`. Stop and ask on any unexpected destroy or replace.
- `gcloud` and `kubectl` against existing resources are fine for operating and measuring. Creating, deleting or changing cloud resources outside OpenTofu is not.
- Never expose `kubectl proxy` or `port-forward` to the LAN: it exposes the whole Kubernetes API. Bind to localhost.
- `infra/backend.tf`, `infra/*.tfvars` and `slides/.env` are git-ignored: project ids, billing accounts and tokens never go in the repo.
- Commits: Conventional Commits, atomic.
- Comments only where the code is too terse; no names, dates or history in comments. Module docstring: one short sentence.
- Code, commits and agent docs in English; README and slides in Spanish.
- Measurements: run long jobs under `caffeinate -i`. Use `set -o pipefail` or check exit codes. Verify image push dates before measuring variants. When measuring rebuilds, make each edit unique or the layer cache contaminates it.
- Keep every `tofu plan`/`apply` and every cluster measurement in the main thread, not in subagents.
- Several GCP projects from one checkout: give each its own `TF_DATA_DIR`, `-backend-config` and `-var-file`, and pass the same `-var-file` again when applying a saved plan (`terraform.tfvars` is auto-loaded).
