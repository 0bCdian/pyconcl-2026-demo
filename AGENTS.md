# Working on this repo

Demo and deck for the PyCon Chile 2026 talk "Misma app, dos resultados distintos: buenas prácticas para desplegar Python en contenedores". 30 minutes, in person in Santiago on 14 November 2026 at 16:45, online on 15 November. The bar is "tiene que salir impecable".

Read first: `README.md` (results and how to reproduce each number), `ARCHITECTURE.md` (components, order flow, technologies), `PRODUCT.md` (audience and tone of the deck), `CHECKLIST.md` (the practices).

## What the talk must be

- Evidence, not a sales pitch. Simple. Every number on a slide comes from a script in `benchmarks/` and says where it was measured.
- The app must be as real as possible: no synthetic tests that do not match day-to-day production. The shop charges a payment service and stores the order in PostgreSQL, so a killed process leaves a charge without an order.
- The talk is about Python in containers, not about Kubernetes. Both versions get the same manifest; only the image and how the process starts differ.
- The audience buys from their phones (the arena) and sees each version's board on the projector.

## Rules

- **Google Cloud sandbox `my-sandbox-project`: change it only through OpenTofu (`infra/`).** Show the plan to Diego and wait for approval before every apply. Save the plan with `-out` and apply that file. Never `-auto-approve`. Never `tofu destroy`. Read every plan for unexpected destroy or replace and stop to ask if there is one.
- `gcloud` and `kubectl` against existing resources are fine for operating and measuring. Creating, deleting or changing Google Cloud resources outside tofu is not.
- Never expose `kubectl proxy` or `port-forward` to the LAN: it exposes the whole Kubernetes API. Bind to localhost.
- Commits: Conventional Commits, atomic. Push to `origin` (`0bCdian/pyconcl-2026-demo`, private) when the work is verified.
- Comments only where the code is too terse; no names, dates or history in comments. Module docstring: one short sentence.
- Code, commits and agent docs in English; README, ARCHITECTURE, CHECKLIST and slides in Spanish.
- Measurements: run long jobs under `caffeinate -i` (the Mac sleeps and hangs them). Use `set -o pipefail` or check exit codes yourself; a `| tail` hid a failed Cloud Build once. Verify image push dates before measuring variants. When measuring rebuilds, make each edit unique or the layer cache from an earlier run contaminates it.
- Keep every `tofu plan`/`apply` and every cluster measurement in the main thread, not in subagents: a subagent cannot show the plan and wait. Give subagents a concrete acceptance check (`tofu validate`, `kustomize build`, `actionlint`).

## State on 11 November 2026, evening

- **Cluster down** (`make down` ran). In tofu state remain only the cheap parts: network, registry, buckets, service accounts and the two VM firewall rules.
- **Orphan disk `pvc-f58b3ff7-7802-4ec2-855d-6465368f069e`** (10 GB, europe-west1-b, about 1 USD per month). A measurement script recreated the `demo` namespace while `make down` ran, and the cluster was deleted before the disk. Delete it only with Diego's approval. The scripts now stop when the cluster goes away and `make down` waits for the volume.
- `internal-gateway-ip` (reserved internal address) is not in this repo's state. Do not touch it.
- All work is committed and pushed to `main`.

### Measured on GKE today

Raw output in `benchmarks/results/2026-11-11/`. PostgreSQL with CloudNativePG, 30% orders load mix, spot `e2-standard-8` node per version, 2 pods of 1 CPU and 2 GiB.

| | A (bad) | + 1 worker | + `exec` | B (good) |
|---|---|---|---|---|
| Memory per pod at 200 rps | 1,430 MiB | 112 MiB | 110 MiB | 95 MiB |
| 550 rps peak | ~300 ok/s, p95 > 5 s, 100% throttling | 550 ok/s, p95 ≈ 280 ms | 550 ok/s, p95 ≈ 275 ms | 550 ok/s, p95 ≈ 255 ms |
| Deploy at 200 orders/s: client errors | 30–31 | 28 | 2 | 0–1 |
| Deploy: charged without order | 26–30 | 26 | 0 | 0 |

A and B: 3 runs. Middle columns: 1 run each. Also measured once:

- `exec` alone: deploy 1 error, 0 charged without order; memory and peak as bad as A.
- `PYTHON_CPU_COUNT=1` (3 workers): 279 MiB, 550 ok/s with p95 ≈ 290 ms, deploy 32 errors and 26 charged without order.
- DEBUG logging: 1,426 MiB, ~280 ok/s at the peak, deploy 31 errors and 25 charged without order.
- Breaking point, ramp 100 → 1,500 rps: A breaks at ~450 rps and serves ~270–300 ok/s beyond. B holds to ~710 rps, then p95 > 5 s while still serving ~550–640 ok/s.
- Image pull on a cold node: A 16.0 s (545 MB compressed), B 5.1 s (114 MB).
- Grafana A/B legends checked: every panel query returns series `A` and `B`.

Podman measurements (image, CVEs, rebuilds, `--preload`, code lessons) are in the README and were redone on 11 November.

### Claims in README and deck that today's data contradicts

- B's breaking point is ~710 rps, not ~650.
- "Sobre ~650 rps B cae más que A" is not supported: above its knee B still serves about twice what A serves, with similar errors per second. One run.
- "1 worker: pocas cobradas sin orden (4)" is wrong: 26. Without `exec` the SIGKILL still arrives.
- `PYTHON_CPU_COUNT=1` also gives 26 charged without order.
- Memory: A is ~1,430 MiB (was 1,375), B ~95 MiB (was 90). "24–30 cobradas" becomes 26–30. B's deploy errors become 0–1.
- Slide 13 has a `PENDIENTE` for the cold-node pull: fill it with 16.0 s / 5.1 s.
- The README GKE tables still say they predate PostgreSQL; replace them with today's numbers.

## Decisions Diego still has to make

Asked on 11 November, not answered yet. My recommendation after each.

1. **How the audience feels the degradation.** At the base load of 200 rps both versions look identical. Options: Diego triggers the peak by hand; constant load in A's broken zone; automatic waves. Recommended: base 200 rps plus a 550 rps wave of 90 s every 5 minutes.
2. **Live commit.** Recommended: one push of a one-line visible change around minute 10, so the audience sees the build race, ArgoCD and A losing orders in its rollout. Keep a recording as backup.
3. **How the SHA reaches `main`.** Recommended: each version's job commits its own SHA as soon as its image is pushed (real race), bot pushes straight to `main`, path filters so the bot commit does not trigger a build.
4. **ArgoCD webhook or polling.** Recommended: polling every 30 s, ArgoCD stays private. Diego creates the GitHub App (Contents: read-only), installs it on the repo and provides App ID, Installation ID and the private key path.
5. **GitOps scope.** Recommended: ArgoCD manages only the `demo` namespace; Prometheus, Grafana and the operators stay on Helm via `make`.
6. **Public URL for phones.** The Cloudflare quick tunnel (`make tunnel`) caps at 200 concurrent requests and has not been tested. Recommended: Diego's domain, an address and managed certificate in tofu, only the arena public.
7. **Workload Identity Federation from Diego's personal GitHub into the company sandbox.** Recommended: restricted to this repo and `main`, a service account that can only write to this registry. An organization policy may block it.
8. **Summary table.** Recommended: live numbers from the session for what happened in it, measured values as fallback, fixed values for image, CVEs and pull.
9. **Middle steps of the ladder and the VM.** Recommended: slides only; live there are only A and B.
10. **Public repo for the talk.** Recommended: yes, after checking the history for secrets.

Also open: confirm the speaker name on the cover, values for `slides/.env`, and whether to delete the redundant remote branch `charla`.

## Plan agreed so far

### Deck as a crescendo

Diego wants the deck to introduce one practice at a time and show what each improves, then a demo that shows all the improvements. Proposed ladder, numbers above:

0. Version A as is.
1. Workers sized from the container, not the node: memory, the 550 rps peak, startup, database connections (170 → 10 per pod).
2. Plus the signal reaching the process (`exec`): deploy errors and charges without order go to 0, shutdown 30 s → 0.6 s.
3. Plus a slim two-stage image with a lockfile: size, pull, CVEs, rebuild time, new layers per code change.

Then one demo block with the peak and a deploy, A against B, and a summary table. The QR goes at the start so the arena has history by the time of the demo.

### `os.cpu_count()` on a VM against a pod

The point: you have to know where your app runs. `cpu_count() * 2 + 1` is gunicorn's documented formula and is right on a VM (8 cores, 17 workers, 8 real CPUs) and wrong in a pod with 1 CPU. `infra/vm.tf` creates `pycon-vm` (same machine type as the version nodes) and `scripts/vm.sh` installs version A on it with pip under systemd, using the cluster's PostgreSQL and payments through the NodePorts in `k8s/vm.yaml`.

- OS Login does not work: the identity belongs to another organization and needs `roles/compute.osLoginExternalUser` there. So the VM has OS Login off and a dedicated key in metadata (`vm_ssh_public_key_file`, default `~/.ssh/pycon-vm.pub`). On a new machine, create it: `ssh-keygen -t ed25519 -f ~/.ssh/pycon-vm -C pycon-vm`. The plan will show the key change.
- `scripts/vm.sh` uses plain `ssh` with an IAP `ProxyCommand`, not `gcloud compute ssh`, which could write keys into project metadata outside tofu. Untested.
- Still to measure: the 550 rps peak and the ramp against the VM, next to the pod.

### CI/CD with GitHub Actions and ArgoCD

Diego's design, to build after the measurements (ArgoCD reverts `kubectl set image`, which the measurement scripts use):

- OpenTofu creates all infrastructure: APIs, network, firewall, IAP, addresses, GKE, VM, Artifact Registry, Workload Identity Federation for GitHub.
- GitHub Actions replaces Cloud Build: builds the images, tags them with the commit SHA (never `latest`), and records the time of each Docker build stage for A and B.
- The workflow commits the new SHAs to the manifests on `main` automatically.
- ArgoCD, connected through a GitHub App on Diego's account, deploys whatever changed.
- Show on stage: time from commit to deployed for each version, and the layer cache effect (A rebuilds 311 MB of dependencies per code change, B 0.01 MB).
- Removing Cloud Build will show its service account and staging bucket as destroyed in the plan; that is expected. The single-practice variants (`benchmarks/gke/variants/`) need a manual workflow instead.
- Document the pipeline in `ARCHITECTURE.md` when it exists.

## Next cluster session

`make plan SPOT=true`, show it, then apply the saved plan and run the rest of `make up`. In one session:

1. `benchmarks/gke/parallel.sh` (workers per pod against pods with the same 2 CPUs).
2. `--preload` on GKE, `benchmarks/gke/pools.sh`.
3. VM against pod (`scripts/vm.sh`, then load against `http://<vm_address>:8000`).
4. PostgreSQL with its default `max_connections` (100): A opens 170 connections per pod.
5. Fallback captures for the deck into `slides/public/fallback/` (`panel-6/7/10/13.png`, `arena.png`).
6. The tunnel with real phones, if Diego approves it.
7. CI build timing, then ArgoCD last.

Afterwards: rewrite the deck as the ladder with the summary table, update README numbers, export PDF (`pnpm approve-builds` first), and a timed rehearsal with real phones.
