# 15 de noviembre de 2026

Mediciones de la versión final de la charla. Podman en un MacBook (Apple M5, VM de Podman con 8 vCPU y 6 GiB) y GCP (`europe-west1`, nodos spot `e2-standard-8`).

## Podman: las demos (`scripts/demo.sh`, 3 corridas)

`make local` arriba; `demo.sh start` detiene sus réplicas para que solo los contenedores de la demo usen la base.

| | A | B |
|---|---|---|
| Rebuild tras cambiar 1 línea (`demo.sh build`, con `--pull=never`) | 19,9 / 21,1 / 21,1 s | 3,6 / 3,5 / 3,5 s |
| Arranque hasta el primer 200, 1 CPU (`demo.sh start`) | 11,5 / 11,3 / 11,2 s, 18 procesos | 2,2 / 2,2 / 2,2 s, 1 proceso |
| Apagado (`demo.sh stop`) | 10,2 / 10,3 / 10,3 s, exit 137 | 0,5 / 0,4 / 0,4 s, exit 0 |
| Imagen | 1,46 GB | 392 MB |

- Sin `--pull=never`, cada `FROM` consulta el registry y suma ~7 s a los dos builds; con el contexto de build completo (sin la lista blanca de `.dockerignore`) se sumaba además `slides/node_modules`.
- Con las 2 réplicas de A de `make local` corriendo, una tercera copia de A agotó `max_connections=500` de PostgreSQL (`TooManyConnectionsError: sorry, too many clients already`) y gunicorn salió con exit 3.

## GKE (2 pods de 1 CPU y 2 GiB por versión)

| | A | B | Cómo |
|---|---|---|---|
| Réplica nueva en nodo frío: pod creado → Ready | 39 y 45 s | 13 y 13 s | primer deploy en nodos nuevos, `creationTimestamp` contra la condición Ready |
| Pull de la imagen en ese nodo | 21,4 s | 7,0 s | eventos `Pulled` |
| Arranque con la imagen ya en el nodo: pod creado → primer 200 | 20,5 / 22,1 / 26,3 s | 5,4 / 4,9 / 5,1 s | `make startup` ×3 |
| Rollout de 2 réplicas hasta "successfully rolled out" | 43 / 43 / 47 s | 11 / 8 / 12 s | `kubectl rollout restart` + `rollout status` |
| Rollout hasta que no quedan pods viejos | 84 / 84 / 88 s | 28 / 25 / 29 s | igual, contando pods |
| Build completo en Cloud Build, sin caché | 79,1 s | 82,4 s | `make images`, duración de cada paso |

## VM `e2-standard-8` sin contenedor (`scripts/vm.sh`)

La versión A con el mismo `start.sh` y `gunicorn_conf.py`, instalada con pip bajo systemd, contra PostgreSQL y pagos del cluster. Carga con k6 desde el cluster (`TARGETS=vm=http://<vm_address>:8000`, 30% órdenes).

- `nproc` = 8, gunicorn levanta 17 workers.
- 200 rps durante 90 s: 0% de errores, p95 210 ms, memoria del servicio 1.449 MiB.
- 550 rps durante 3 min: 0% de errores (98.989 requests), p95 212 ms, memoria 1.471 MiB, carga 1,8 sobre 8 núcleos.

## Cloud Run, 1 vCPU y 2 GiB (`gcloud run jobs execute pycon-cpu-probe`)

El job de `infra/cloudrun.tf` imprime lo que ve Python dentro de la imagen A. Tres ejecuciones:

| Ejecución | `os.cpu_count()` | `os.process_cpu_count()` | cgroup `cpu.max` | Workers con `cpu_count()*2+1` |
|---|---|---|---|---|
| 1 | 6 | 6 | no existe | 13 |
| 2 | 6 | 6 | no existe | 13 |
| 3 | 5 | 5 | no existe | 11 |
