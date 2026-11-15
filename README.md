# Misma app, dos resultados distintos

Demo de la charla de PyCon Chile 2026 sobre buenas prácticas para desplegar Python en contenedores.

Una API FastAPI (`app/app.py`) se despliega de dos maneras: A, como en el tutorial (`deploy/bad/`), y B, bien hecha (`deploy/good/`). El código Python es el mismo. Cambian el Dockerfile y cómo arranca el proceso. En Kubernetes las dos usan el mismo manifiesto.

## Estructura

```
app/          la tienda: catálogo y órdenes (cobran en pagos y se guardan en PostgreSQL)
deploy/       Dockerfile y arranque de A (bad) y B (good)
payments/     mock de la pasarela de pagos; GET /reconciliation cruza cobros y órdenes
arena/        tablero en vivo: manda la misma orden a A y B y cuenta errores y cobradas sin orden
db/           schema.sql
k6/           la carga: 30% órdenes, 70% lecturas
k8s/          manifiestos: apps, PostgreSQL (CloudNativePG), k6, Prometheus y Grafana
infra/        OpenTofu: red, GKE, Artifact Registry, bucket del catálogo; bootstrap/ crea el proyecto
scripts/      local.sh, demo.sh, startup.sh, vm.sh
benchmarks/   scripts que reproducen los números; results/ tiene los logs de GKE
slides/       el deck (Slidev)
```

## Requisitos

- Local: `podman`, `k6`, `uv`.
- GCP: `tofu`, `gcloud` (con `gke-gcloud-auth-plugin`), `kubectl`, `helm`.
- Deck: `pnpm`.

## En tu máquina

```bash
make local              # PostgreSQL, pagos, 2 réplicas por versión, un balanceador por versión y la arena
make local-load         # k6 contra A y B (RATE, DURATION)
make local-down

scripts/demo.sh build   # reconstruye A y B tras cambiar una línea
scripts/demo.sh start   # arranque hasta el primer 200
scripts/demo.sh stop    # apagado
```

La arena queda en `http://localhost:8080/screen?token=...` (el comando imprime la URL). `demo.sh` necesita `make local` arriba.

## En tu proyecto de GCP

1. Proyecto nuevo: en `infra/bootstrap/` copia `terraform.tfvars.example` a `terraform.tfvars`, completa `project_id` y `billing_account`, y corre `tofu init && tofu apply`. Crea el proyecto, las APIs, el bucket de estado y un presupuesto. Proyecto existente: sáltate este paso.
2. En `infra/` copia `terraform.tfvars.example` a `terraform.tfvars` y `backend.tf.example` a `backend.tf` (con `bucket = "<project_id>-tofu-state"`). Los dos están en `.gitignore`. Sin `backend.tf` el estado queda local.
3. Desde la raíz:

```bash
make init
make plan SPOT=true     # revisa el plan
make up SPOT=true       # tofu apply, imágenes en Cloud Build, Prometheus/Grafana, CloudNativePG y las apps
make proxy              # Grafana, Prometheus y la arena en localhost:8001
make load RATE=200      # k6 dentro del cluster, misma carga para A y B (RATE, DURATION, MEMORY)
make rollout            # redeploy de A y B en medio de la carga
make startup            # segundos desde que se crea un pod hasta su primer 200
make down               # borra el namespace demo y apaga cluster y nodos (stage=off)
```

Son 3 nodos: un `e2-standard-8` por versión y un `e2-standard-4` para k6, monitoreo, pagos y PostgreSQL. Cuesta cerca de 1 USD por hora; con `SPOT=true`, menos. Con `stage=off` quedan solo red, registry, buckets y service accounts.

`make images` reconstruye las imágenes, `make deploy` vuelve a aplicar los manifiestos y `make status` lista los pods. La VM y el job de Cloud Run se crean con `tofu -chdir=infra apply -var stage=on -var vm_and_cloud_run=true`; `scripts/vm.sh` instala A en la VM.

Las dos versiones leen el catálogo de un bucket con Workload Identity, sin llaves.

## Resultados

| | A (`deploy/bad`) | B (`deploy/good`) | Dónde y cuándo |
|---|---|---|---|
| Memoria por pod, 200 rps | 1.430 MiB | 95 MiB | GKE, 11 nov |
| Conexiones a la base | 170 | 10 | local |
| Servidas en un peak de 550 rps | ~300/s, p95 > 5 s | 550/s, p95 ≈ 255 ms | GKE, 11 nov |
| Cobradas sin orden en un deploy | 26–30 | 0 | GKE, 11 nov |
| Réplica nueva en nodo frío | 39–45 s | 13 s | GKE, 15 nov |
| Rollout de 2 réplicas | 43–47 s | 8–12 s | GKE, 15 nov |
| Arranque hasta el primer 200 (Podman) | 11 s | 2,2 s | Podman, 15 nov |
| Apagado (Podman) | 10 s, exit 137 | 0,4 s, exit 0 | Podman, 15 nov |
| Rebuild tras cambiar 1 línea | 20–21 s | 3,5 s | Podman, 15 nov |
| Capas nuevas por deploy | 311 MB | 0,01 MB | Podman, 11 nov |
| Imagen | 1,46 GB | 392 MB | Podman |
| `os.cpu_count()` con 1 CPU de límite | 8 (pod, 17 workers); 5–6 (Cloud Run, 11–13 workers) | no se usa: 1 worker | GKE y Cloud Run, 15 nov |

Los números cambian según la máquina; lo que se mantiene es la diferencia entre A y B. Los logs de GKE están en `benchmarks/results/2026-11-11/`.

## Reproducir cada número

| Número | Comando |
|---|---|
| Imagen, arranque, memoria y apagado en Podman | `benchmarks/containers.sh` |
| Paquetes, vulnerabilidades, rebuild y capas nuevas | `benchmarks/image.sh` |
| Variantes de A con una práctica cada vez, en Podman | `benchmarks/gke/local-ablation.sh` |
| Rebuild, arranque y apagado en vivo | `scripts/demo.sh build`, `start`, `stop` |
| Memoria, peak y deploy en GKE: A y B tal cual | `benchmarks/gke/baseline.sh 3` |
| Lo mismo con una práctica cada vez | `benchmarks/gke/build.sh && benchmarks/gke/ablation.sh` |
| Memoria por pod | `make load RATE=200 DURATION=90s`, luego `benchmarks/gke/resources.sh` |
| Peak de 550 rps | `make load RATE=550 DURATION=3m`, luego `benchmarks/gke/watch.sh` |
| Cobradas sin orden en un deploy | `benchmarks/gke/charges.sh rollout` |
| Arranque en GKE | `make startup` |
| Rollout en GKE | `make rollout` y `kubectl -n demo rollout status deploy/bad` |
| Cloud Run | `gcloud run jobs execute pycon-cpu-probe` |
| VM sin contenedor | `vm_and_cloud_run = true` en tofu, `scripts/vm.sh`, y k6 con `TARGETS=vm=http://<vm_address>:8000` |
| Conexiones a PostgreSQL por pod | `kubectl -n demo exec postgres-1 -c postgres -- psql -U postgres -d shop -c "select usename, count(*) from pg_stat_activity group by 1"` |
| Pull y réplica nueva en nodo frío | tras crear el cluster: eventos `Pulled` (`kubectl -n demo get events --field-selector reason=Pulled`) y la condición Ready de cada pod contra su `creationTimestamp` |
| Build completo sin caché | `make images`, luego `gcloud builds describe <id>` (duración de cada paso) |
| Lint de los Dockerfiles | `make lint` |

## Deck

```bash
cd slides && cp .env.example .env && pnpm install && pnpm dev
```
