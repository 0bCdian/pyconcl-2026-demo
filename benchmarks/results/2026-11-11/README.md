# GKE, 11 de noviembre de 2026

Salidas sin editar de los scripts de `benchmarks/gke/`, con PostgreSQL (CloudNativePG) y la mezcla de carga actual (30% órdenes). Nodos spot `e2-standard-8` por versión, 2 pods de 1 CPU y 2 GiB.

| Archivo | Script | Corridas |
|---|---|---|
| `baseline.log` | `baseline.sh 3`: A y B tal cual | 3 |
| `ablation-cpucount1-debug.log` | `ablation.sh cpucount1 debug` | 1 |
| `ablation-workers1-exec.log` | `ablation.sh workers1 exec` | 1 |
| `ablation-workers1-exec-combined.log` | `ablation.sh workers1-exec`: las dos prácticas juntas | 1 |
| `stress.log` | `make stress`, luego `watch.sh 22`: rampa de 100 a 1.500 rps | 1 |
| `parallel-interrupted.log` | `parallel.sh`, cortado al apagar el cluster | incompleto |

En `parallel-interrupted.log` solo valen las líneas de memoria y procesos de `cgroup-1cpu` y `cgroup-2cpu`; no llegó a calcular el punto de quiebre de ninguna variante. El bloque `workers1-2cpu` corrió mientras se borraba el namespace y no vale.

La primera pasada de la ablación usó imágenes `bad-workers1` y `bad-exec` anteriores a PostgreSQL, en las que todas las órdenes fallaban. Esos bloques se descartaron; `ablation-workers1-exec.log` es la repetición con las imágenes correctas.
