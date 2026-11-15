# Working on this repo

Demo and deck for the PyCon Chile 2026 talk "Misma app, dos resultados distintos: buenas prácticas para desplegar Python en contenedores". 30 minutes, online on 15 November 2026 at 16:00 Madrid time. The bar is "tiene que salir impecable".

Read first: `README.md` (results and how to reproduce each number), `ARCHITECTURE.md` (components, order flow, technologies), `PRODUCT.md` (audience and tone of the deck), `CHECKLIST.md` (the practices).

## What the talk is

- Good practices for deploying Python in containers, and what not following them costs: slow builds, slow autoscaling, slow deploys that lose orders, and memory and CPU waste because `os.cpu_count()` sees the machine, not the container's limit (VM against GKE pod against Cloud Run).
- Evidence, not a sales pitch. Every number on a slide says where and when it was measured. Slides show results only; load tests are not live.
- Three live demos, all local: `scripts/demo.sh build`, `start`, `stop` (bad against good with `time`). Needs `make local` running.
- Out of scope: phones and the arena storefront, Grafana in the slides, code lessons, CI/CD with ArgoCD.

## Rules

- **Google Cloud sandbox `my-sandbox-project`: change it only through OpenTofu (`infra/`).** Show the plan to Diego and wait for approval before every apply. Save the plan with `-out` and apply that file. Never `-auto-approve`. Never `tofu destroy`. Read every plan for unexpected destroy or replace and stop to ask if there is one.
- `gcloud` and `kubectl` against existing resources are fine for operating and measuring. Creating, deleting or changing Google Cloud resources outside tofu is not.
- Never expose `kubectl proxy` or `port-forward` to the LAN: it exposes the whole Kubernetes API. Bind to localhost.
- Commits: Conventional Commits, atomic. Push to `origin` (`0bCdian/pyconcl-2026-demo`, private) when the work is verified.
- Comments only where the code is too terse; no names, dates or history in comments. Module docstring: one short sentence.
- Code, commits and agent docs in English; README, ARCHITECTURE, CHECKLIST and slides in Spanish.
- Measurements: run long jobs under `caffeinate -i` (the Mac sleeps and hangs them). Use `set -o pipefail` or check exit codes yourself; a `| tail` hid a failed Cloud Build once. Verify image push dates before measuring variants. When measuring rebuilds, make each edit unique or the layer cache from an earlier run contaminates it.
- Keep every `tofu plan`/`apply` and every cluster measurement in the main thread, not in subagents: a subagent cannot show the plan and wait. Give subagents a concrete acceptance check (`tofu validate`, `kustomize build`, `actionlint`).

## State on 15 November 2026

- Deck: `slides/slides.md`, 13 slides, no placeholders left. Numbers come from `benchmarks/results/2026-11-11/` (memory, peak, deploy losses on GKE) and `benchmarks/results/2026-11-15/` (demos, cold-node startup, rollout, Cloud Build, VM, Cloud Run).
- GCP sandbox is up with spot nodes: cluster, VM `pycon-vm` and the Cloud Run job `pycon-cpu-probe`. Turn it off with `make down` when no longer needed (it asks for confirmation).
- The Artifact Registry was found deleted outside tofu on 15 November; the plan recreated it and `make images` rebuilt the images.
- Orphan disk `pvc-f58b3ff7-7802-4ec2-855d-6465368f069e` (10 GB) still exists; delete it only with Diego's approval.
- `.dockerignore` is a whitelist (`app/`, `deploy/`): the build context used to include `slides/node_modules`.
- On this Podman, each `FROM` checks the registry (~7 s); the build demo uses `--pull=never`.
