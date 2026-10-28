# Mismo código, distinto destino

Demo de la charla en PyCon Chile 2026: buenas prácticas para llevar tu app Python a producción.

Una sola API FastAPI (`app/app.py`) se despliega de dos maneras: "como en el tutorial" (`deploy/bad/`) y bien hecha (`deploy/good/`). El código Python es el mismo; cambian solo el Dockerfile, cómo se arranca el proceso y el manifiesto de Kubernetes.

```
app/          el código: una tienda con catálogo (pandas, leído de GCS en GKE) y órdenes que llaman a un servicio de pagos
deploy/bad/   python:3.13 completo, pip, CMD en forma shell, start.sh sin exec, workers = cpu_count()*2+1
deploy/good/  slim multi-stage, uv con bytecode precompilado, UID 1000, CMD en forma exec, 1 worker
payments/     mock de la pasarela de pagos (latencia configurable)
k8s/          las dos versiones en nodos idénticos, k6, Prometheus y Grafana
infra/        OpenTofu: red, GKE, Artifact Registry, el bucket del catálogo y Workload Identity
infra/bootstrap/  para empezar desde cero: proyecto, facturación, APIs, bucket de estado y presupuesto
benchmarks/   los scripts que reproducen cada número de la charla
```

## Resultados

Medidos con `benchmarks/containers.sh` (Podman, cada contenedor limitado a 1 CPU, en un host de 8 núcleos):

| | `deploy/bad` | `deploy/good` |
|---|---|---|
| Imagen | 1,55 GB | 377 MB |
| Arranque hasta el primer 200 | 6–9 s | ~0,9 s (1,6 s sin bytecode precompilado) |
| `os.cpu_count()` con 1 CPU de límite | 8, y gunicorn levanta 17 workers (3 con `PYTHON_CPU_COUNT=1`, sin tocar su configuración) | no se usa: 1 worker |
| 60 s en reposo con 1 GiB | 70–80 procesos muertos por OOM | 0 |
| 100 rps con 1 GiB | entre 28% y 81% de errores según la corrida (los OOM son aleatorios) | 0%, p95 ≈ 220 ms |
| 300 rps con 1 GiB | entre 71% y 99,8% de errores | 0%, p95 ≈ 218 ms |
| 100 y 300 rps con 2 GiB | 0%, p95 ≈ 216–219 ms | |
| Apagado | 30 s y exit 137 (incluso con `CMD` en JSON, porque `start.sh` no hace `exec`) | 0,4 s y exit 0 |

Con el doble de memoria la versión mala rinde igual: el costo de desplegar mal se paga en memoria, en arranques lentos y en deploys que cortan requests.

Lecciones que sí requieren cambiar el código, medidas con `benchmarks/code/run.sh` (1 worker de uvicorn):

| | Resultado |
|---|---|
| `async def` + `requests` a un servicio de ~150 ms, 100 rps | ~95% de errores: el event loop bloqueado no acepta conexiones (en macOS se ven como *connection reset*; en Linux, como timeouts) |
| `def` + `requests`, 200 rps | 0% de errores, p95 ≈ 222 ms |
| `def` + `requests`, 400 rps | sin errores, pero p95 ≈ 3,9 s y ~7.200 iteraciones descartadas |
| el mismo `def`, subiendo el threadpool de AnyIO de 40 a 200 hilos, 400 rps | 0% de errores, p95 ≈ 219 ms: el límite eran los 40 hilos |
| `async def` + `httpx.AsyncClient`, 400 rps | 0% de errores, p95 ≈ 221 ms |
| `log.debug(f"... {json.dumps(catalogo)}")` con DEBUG desactivado | 463 contra 934 rps sin logs (−50%), sin escribir un solo byte |
| `log.info` con el payload completo | −3% de throughput, pero 30 MB de log en 15 s |

Los números cambian según la máquina; lo que se mantiene es la diferencia entre ambas versiones.

## Credenciales

En GKE las dos versiones leen el catálogo desde un bucket con `storage.Client()`, que usa las credenciales por defecto (ADC), y las dos se autentican con Workload Identity: la cuenta de Kubernetes recibe el permiso directamente, sin llaves. No es parte de la comparación; es la base sobre la que se compara.

## Correrlo en GKE

Requisitos: `tofu`, `gcloud` (con `gke-gcloud-auth-plugin`), `kubectl`, `helm`.

Proyecto nuevo: primero `infra/bootstrap/` (ver su README). Proyecto existente: copia `infra/terraform.tfvars.example` a `infra/terraform.tfvars` y, si quieres el estado en GCS, `infra/backend.tf.example` a `infra/backend.tf`.

```bash
make init
make plan SPOT=true    # revisa el plan
make up SPOT=true      # tofu apply (pide confirmación) + imágenes en Cloud Build + Prometheus/Grafana + apps
make grafana           # http://localhost:3000 (admin / pycon)
make load RATE=100     # k6 dentro del cluster: misma tasa para bad y good durante 30 min
make rollout           # deploy de ambos en medio de la carga
make startup           # segundos desde que se crea un pod hasta su primer 200
make down              # tofu apply con stage=off: borra el cluster y los nodos
```

Tres nodos: un `e2-standard-8` por versión y un `e2-standard-4` para k6, el monitoreo y el mock de pagos. Estimamos alrededor de 1 USD por hora (sin verificar los precios de la región); con `SPOT=true`, bastante menos. `MEMORY=2Gi` iguala el rendimiento de la versión mala. Con `stage=off` quedan solo la red, el registry, los buckets y las service accounts, sin costo relevante.

## Correr los benchmarks en tu máquina

```bash
./benchmarks/containers.sh   # Podman (o CONTAINER=docker) + k6; unos 15 minutos
./benchmarks/code/run.sh     # uv + k6; unos 6 minutos
make lint                    # hadolint sobre los dos Dockerfiles
```

Las buenas prácticas están en [CHECKLIST.md](CHECKLIST.md).
