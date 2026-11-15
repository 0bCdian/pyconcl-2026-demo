# Working on this repo

Demo and deck for the PyCon Chile 2026 talk "Misma app, dos resultados distintos". `README.md` explains how to run it and reproduce each number.

## Rules

- **Google Cloud sandbox `my-sandbox-project`: change it only through OpenTofu (`infra/`).** Show the plan to Diego and wait for approval before every apply. Save the plan with `-out` and apply that file. Never `-auto-approve`. Never `tofu destroy`. Read every plan for unexpected destroy or replace and stop to ask if there is one.
- `gcloud` and `kubectl` against existing resources are fine for operating and measuring. Creating, deleting or changing Google Cloud resources outside tofu is not.
- Never expose `kubectl proxy` or `port-forward` to the LAN: it exposes the whole Kubernetes API. Bind to localhost.
- Commits: Conventional Commits, atomic.
- Comments only where the code is too terse; no names, dates or history in comments. Module docstring: one short sentence.
- Code, commits and agent docs in English; README and slides in Spanish.
- Measurements: run long jobs under `caffeinate -i`. Use `set -o pipefail` or check exit codes; a `| tail` once hid a failed Cloud Build. Verify image push dates before measuring variants. When measuring rebuilds, make each edit unique or the layer cache contaminates it.
- Keep every `tofu plan`/`apply` and every cluster measurement in the main thread, not in subagents.

## Two Google Cloud projects

- `my-sandbox-project` (company sandbox, account in the gcloud `default` configuration): `infra/backend.tf` and `infra/terraform.tfvars` point here, with the default `.terraform/` directory.
- `my-project` (Diego's personal project, gcloud configuration `pycon`): the cluster for the talk. Nodes are private, with Cloud NAT; no VM or Cloud Run probe (`vm_and_cloud_run = false`).
- Work on the personal project with its own state and token, from the repo root:
  ```sh
  export TF_DATA_DIR=.terraform-personal GOOGLE_OAUTH_ACCESS_TOKEN=$(gcloud auth print-access-token --configuration pycon)
  tofu -chdir=infra plan -var-file=personal.tfvars -var stage=on -out=up.tfplan
  tofu -chdir=infra apply -var-file=personal.tfvars -var stage=on up.tfplan   # the same -var-file is required: terraform.tfvars is auto-loaded
  make kubeconfig images monitoring cnpg deploy
  ```
  `infra/personal.tfvars` (git-ignored) holds `project_id`, `region` and `zone`; the backend is set with `tofu init -backend-config=bucket=my-project-tofu-state -backend-config=prefix=pycon` under that `TF_DATA_DIR`.
- `infra/bootstrap/` has a local state for the personal project: APIs, the state bucket and a 30 EUR budget.
- Diego authorized applying plans in the personal project without asking when they only create or change. Destroy or replace still needs his approval.
