# Misma app, dos resultados distintos

Demo de la charla en PyCon Chile 2026: buenas prácticas para desplegar Python en contenedores.

Una sola API FastAPI (`app/app.py`) se despliega de dos maneras: "como en el tutorial" (`deploy/bad/`) y bien hecha (`deploy/good/`). El código Python es el mismo; cambian solo el Dockerfile y cómo se arranca el proceso. El manifiesto de Kubernetes (`k8s/demo.yaml`) es el mismo para las dos: difieren únicamente en el nombre, la imagen, el node pool y la service account.

```
app/          el código: una tienda con catálogo (pandas, leído de GCS en GKE) y órdenes que cobran en el servicio de pagos y se guardan en PostgreSQL
deploy/bad/   python:3.13 completo, pip, CMD en forma shell, start.sh sin exec, workers = cpu_count()*2+1
deploy/good/  slim multi-stage, uv con bytecode precompilado, UID 1000, CMD en forma exec, 1 worker
payments/     mock de la pasarela de pagos (latencia configurable): registra cada cobro y expone `GET /reconciliation`
db/           schema.sql: las tablas `orders` (la tienda) y `charges` (pagos)
arena/        la arena del público: los celulares compran en una tienda y el proyector muestra un tablero por versión
slides/       el deck de la charla (Slidev)
scripts/      `local.sh` (`make local`) y `startup.sh` (`make startup`)
k6/           la carga: 30% órdenes y 70% lecturas del catálogo (`ORDER_SHARE`)
k8s/          las dos versiones en nodos idénticos, PostgreSQL, pagos, la arena, k6, Prometheus y Grafana
infra/        OpenTofu: red, GKE, Artifact Registry, el bucket del catálogo y Workload Identity
infra/bootstrap/  para empezar desde cero: proyecto, facturación, APIs, bucket de estado y presupuesto
benchmarks/   los scripts que reproducen cada número de la charla (ver "Reproducir cada número")
```

## Resultados

> **Re-medición pendiente.** Las cifras de "Resultados", "Qué práctica pesa más" y "Cuántos procesos por pod" se midieron antes de agregar PostgreSQL y con la mezcla de carga anterior (70% órdenes). Hoy k6 envía 30% órdenes y 70% lecturas del catálogo, y cada orden además escribe en la base. Se volverán a medir; hasta entonces ninguna cifra cambió.

Medidos con `benchmarks/containers.sh` (Podman, cada contenedor limitado a 1 CPU, en un host de 8 núcleos):

| | `deploy/bad` | `deploy/good` |
|---|---|---|
| Imagen | 1,44 GB | 377 MB |
| Arranque hasta el primer 200 | 10–12 s | ~0,9 s (1,6 s sin bytecode precompilado) |
| `os.cpu_count()` con 1 CPU de límite | 8, y gunicorn levanta 17 workers (3 con `PYTHON_CPU_COUNT=1`, sin tocar su configuración) | no se usa: 1 worker |
| 60 s en reposo con 1 GiB | 70–80 procesos muertos por OOM | 0 |
| 100 rps con 1 GiB | entre 28% y 81% de errores según la corrida (los OOM son aleatorios) | 0%, p95 ≈ 220 ms |
| 300 rps con 1 GiB | entre 71% y 99,8% de errores | 0%, p95 ≈ 218 ms |
| 100 y 300 rps con 2 GiB | 0%, p95 ≈ 216–219 ms | |
| Apagado | 30 s y exit 137 (incluso con `CMD` en JSON, porque `start.sh` no hace `exec`) | 0,4 s y exit 0 |

Con el doble de memoria la versión mala rinde igual mientras sobre CPU: el costo de desplegar mal se paga en memoria, en arranques lentos, en deploys que cortan requests y en los picos.

### Qué práctica pesa más

En GKE, con el mismo manifiesto para las dos (2 pods de 1 CPU y 2 GiB, mismo readiness probe y `preStop`), aplicando a la imagen mala una sola práctica cada vez. Imagen y arranque, en Podman.

"Cobradas sin orden" son los cobros del servicio de pagos que no tienen una orden. Los valores de esta tabla se obtuvieron contando los cobros en el log de pagos y restando las órdenes confirmadas. Ahora se obtienen con una consulta SQL que cruza `charges` y `orders` (`GET /reconciliation` de pagos, ignora los cobros de los últimos 10 s), que ejecuta `benchmarks/gke/charges.sh`.

| Práctica aplicada a la mala | Memoria por pod (200 rps) | Pico de 550 rps | Por deploy (~150 órdenes/s) | Además |
|---|---|---|---|---|
| ninguna | 1.375 MiB | ~300 ok/s, p95 > 5 s, 100% throttling | ~30 errores, 24–30 cobradas sin orden | imagen 1,44 GB, arranque 10–12 s, apagado 30 s |
| 1 worker por contenedor | 107 MiB | 550 ok/s, p95 ≈ 255 ms | ~30 errores, pocas cobradas sin orden (4, una corrida) | arranque 0,7 s |
| `PYTHON_CPU_COUNT=1` (3 workers) | 270 MiB | 550 ok/s, p95 ≈ 225 ms | 28 errores, pocas cobradas sin orden (3, una corrida) | |
| `exec` en `start.sh` | 1.375 MiB | ~330 ok/s, p95 > 5 s | 2 errores, 0 cobradas | apagado 0,6 s |
| imagen slim | igual (en reposo, Podman) | no medido | no medido | imagen 440 MB |
| DEBUG en vez de INFO (al revés) | 1.382 MiB | ~200 ok/s | igual | +31% de CPU a 200 rps |
| todas (`deploy/good`) | 90 MiB | 550 ok/s, p95 ≈ 240 ms | 0 errores, 0 cobradas | imagen 377 MB, arranque 0,9 s, apagado 0,4 s |

Sobre ~650 rps la buena también cae, y queda peor que la mala: con el mismo readiness probe (timeout de 1 s), los de la buena fallan por la sobrecarga y Kubernetes saca sus pods del Service, mientras la mala sigue lista (`make stress`: ~170 contra ~250 rps servidos).

### Cuántos procesos por pod

Dentro del contenedor, `os.cpu_count()` y `os.process_cpu_count()` devuelven los 8 núcleos del nodo; el límite real está en `/sys/fs/cgroup/cpu.max` (`100000 100000` = 1 CPU). También los pools de la biblioteca estándar se dimensionan con los núcleos del nodo: `ThreadPoolExecutor` 12 hilos, `ProcessPoolExecutor` y `multiprocessing.Pool` 8 procesos (con `PYTHON_CPU_COUNT=1`: 5, 1 y 1).

Mismo total de 2 CPUs por versión, rampa de 100 a 1.000 rps, una corrida por fila contra la buena en la misma corrida:

| Distribución | Procesos | Memoria total | Rinde hasta (0 errores, p95 < 300 ms) | La buena, misma corrida |
|---|---|---|---|---|
| 2 pods × 1 CPU, 1 proceso (`deploy/good`) | 2 | 180–210 MiB | ~570–620 rps | |
| 1 pod × 2 CPU, 1 worker por CPU de `cpu.max` | 2 | 191 MiB | ~430 rps | ~570 rps |
| 2 pods × 1 CPU, `cpu.max` × 2 + 1 = 3 workers | 6 | 540 MiB | ~530 rps | ~620 rps |
| 1 pod × 2 CPU, `cpu.max` × 2 + 1 = 5 workers | 5 | 434 MiB | ~520 rps | ~620 rps |
| 1 pod × 2 CPU, 1 proceso | 1 | 110 MiB | ~300 rps, 0% de throttling: el GIL deja una CPU sin usar | ~570 rps |
| 2 pods × 1 CPU, `cpu_count()` × 2 + 1 = 17 workers (`deploy/bad`, en `make stress`) | 34 | 2.750 MiB | ~420 rps | ~560 rps |

Pasado ese punto todas colapsan; las de un solo proceso por pod caen más (a ~90–175 ok/s) porque su único event loop no alcanza a responder el readiness probe y Kubernetes las saca del Service, mientras que con varios workers alguno responde (~250–410 ok/s). Eso habla del probe con el pod saturado, no de más capacidad: la respuesta es escalar antes de llegar ahí.

Si un pod necesita varios workers, que los cuente desde la cuota y no desde el nodo, y que sin límite de CPU no adivine:

```python
def container_cpus() -> int:
    """Whole CPUs granted by the cgroup v2 quota; 1 when the container has no CPU limit."""
    try:
        quota, period = Path("/sys/fs/cgroup/cpu.max").read_text().split()
    except (OSError, ValueError):
        return 1
    if quota == "max":
        return 1
    return max(1, math.ceil(int(quota) / int(period)))

workers = int(os.environ.get("WEB_CONCURRENCY", container_cpus()))
```

OpenBLAS (numpy) también arranca un hilo por núcleo del nodo en cada proceso: la mala corre 144 hilos con 1 CPU y la buena 12. A 550 rps, la mala tiene frenados el 100% de sus periodos de CPU y la buena entre el 4% y el 9%. `OPENBLAS_NUM_THREADS=1` los baja a 25, pero en esta app no cambia ni la memoria ni el pico de 550 rps, porque casi no usa álgebra lineal.

Cada proceso abre además su propio pool de asyncpg, con el valor por defecto de la biblioteca (10 conexiones). Medido a mano con `pg_stat_activity` en Podman, con un contenedor por versión: 170 conexiones la mala (17 workers × 10) y 10 la buena. El manifiesto fija `max_connections=1000` en PostgreSQL (el valor por defecto de PostgreSQL es 100). No se midió qué pasa con el valor por defecto.

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

Estos casos usan apps pequeñas propias (`benchmarks/code/`), sus propios scripts de k6 y un servicio lento de ~150 ms (`slow_service.py`): no usan PostgreSQL ni la mezcla de carga de `k6/test.js`, así que el cambio de la base no los afecta.

Los números cambian según la máquina; lo que se mantiene es la diferencia entre ambas versiones.

## Reproducir cada número

Comandos desde la raíz del repo. Los de GKE necesitan el cluster arriba (`make up`) y las imágenes de las variantes (`benchmarks/gke/build.sh`).

| Número | Comando |
|---|---|
| "Qué práctica pesa más", filas 1 worker, `PYTHON_CPU_COUNT=1`, `exec` y DEBUG | `benchmarks/gke/build.sh && benchmarks/gke/ablation.sh` |
| Misma tabla, filas "ninguna" y "todas": memoria por pod | `make load RATE=200 DURATION=90s`, luego `benchmarks/gke/resources.sh` |
| Misma tabla, pico de 550 rps | `make load RATE=550 DURATION=3m`, luego `benchmarks/gke/watch.sh 7` |
| Misma tabla, columna "Por deploy" | `benchmarks/gke/charges.sh rollout` |
| Imagen, arranque y apagado por variante (Podman) | `benchmarks/gke/local-ablation.sh` |
| Punto de quiebre sobre ~650 rps | `make stress`, luego `benchmarks/gke/watch.sh` |
| "Cuántos procesos por pod" | `benchmarks/gke/build.sh && benchmarks/gke/parallel.sh` |
| Tamaños de los pools de la biblioteca estándar | `benchmarks/gke/pools.sh` |
| Tabla "Resultados" (Podman) | `benchmarks/containers.sh` |
| Tabla de lecciones de código | `benchmarks/code/run.sh` |

Sin script propio: el "+31% de CPU con DEBUG" se calcula a mano comparando dos salidas de `ablation.sh`/`resources.sh` (con DEBUG y con INFO); y las 170 conexiones a PostgreSQL se contaron a mano con `pg_stat_activity`.

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
make proxy             # kubectl proxy: Grafana, Prometheus y la arena en localhost:8001 (los paneles en vivo del deck usan esta URL)
make load RATE=100     # k6 dentro del cluster: misma tasa y misma mezcla (30% órdenes) para bad y good durante 30 min
make rollout           # deploy de ambos en medio de la carga
make startup           # segundos desde que se crea un pod hasta su primer 200
make down              # tofu apply con stage=off: borra el cluster y los nodos
```

`make deploy` (lo ejecuta `make up`) crea también el ConfigMap `db-schema` con `db/schema.sql`, que PostgreSQL carga al iniciar. Tres nodos: un `e2-standard-8` por versión y un `e2-standard-4` para k6, el monitoreo, el mock de pagos y PostgreSQL. Estimamos alrededor de 1 USD por hora (sin verificar los precios de la región); con `SPOT=true`, bastante menos. Las dos versiones tienen los mismos recursos por pod: 1 CPU y `MEMORY` (2 GiB por defecto; con `MEMORY=1Gi` la mala no arranca). Con `stage=off` quedan solo la red, el registry, los buckets y las service accounts, sin costo relevante.

## Correrlo en tu máquina

```bash
make local        # Podman: PostgreSQL, pagos, 2 réplicas por versión con el mismo entorno, un balanceador por versión y la arena
make local-load   # k6 contra las dos versiones (RATE y DURATION)
make local-down
```

`make local` imprime la URL de la pantalla del proyector (con token) y la de los celulares. No tiene readiness ni grace periods como Kubernetes: las diferencias de deploy solo se ven en GKE.

La arena (`arena/`) manda cada toque como la misma orden a las dos versiones. En el celular se ven productos reales de `/products`, un botón COMPRAR y un recibo por versión. En el proyector (`/screen`) hay un tablero por versión con órdenes confirmadas, errores y cobradas sin orden, que sale de `GET /reconciliation`.

## Correr los benchmarks en tu máquina

```bash
./benchmarks/containers.sh   # Podman (o CONTAINER=docker) + k6, con PostgreSQL; unos 15 minutos
./benchmarks/code/run.sh     # uv + k6; unos 6 minutos
make lint                    # hadolint sobre los dos Dockerfiles
```

Las buenas prácticas están en [CHECKLIST.md](CHECKLIST.md).
