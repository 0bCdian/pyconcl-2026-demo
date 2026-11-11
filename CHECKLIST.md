# Checklist para desplegar Python en contenedores

Lo que ningún linter ni test te va a avisar. Las marcadas con 📏 están medidas en `benchmarks/`.

## 1. Dockerfile

La imagen es lo que se descarga cada vez que escalas: chica, reproducible y que arranque rápido.

- [ ] Base `slim` con versión fija, no la imagen completa. 📏
- [ ] Si usas Alpine (musl), comprueba que todas tus dependencias publiquen wheels `musllinux`; si alguna no, se compila en el build.
- [ ] Multi-stage: herramientas de build en una etapa, solo el entorno virtual en la imagen final.
- [ ] Copia primero el lockfile, instala, y después copia el código: así un cambio de código no invalida la capa de dependencias. 📏
- [ ] Bytecode precompilado: `UV_COMPILE_BYTECODE=1` con uv (pip ya lo hace). 📏
- [ ] Usuario no-root con UID numérico (`USER 1000`): Kubernetes no puede verificar `runAsNonRoot` con un nombre.
- [ ] `.dockerignore` con `.git`, `.venv` y `.env`.
- [ ] `CMD` en forma exec (`["uvicorn", ...]`), y `exec` al final de cualquier script de arranque. Hadolint revisa lo primero, no lo segundo. 📏
- [ ] Revisa el Dockerfile con hadolint en CI o pre-commit, sabiendo que solo ve la forma.
- [ ] Reconstruye la imagen periódicamente para tomar los parches de seguridad de la base, aunque tu código no cambie.

## 2. Dónde corre tu código

La plataforma decide cuándo arrancas, cuándo recibes tráfico y cuándo mueres.

- [ ] Maneja `SIGTERM`: termina las requests en curso y sal antes del grace period de la plataforma. 📏
- [ ] Readiness ("ya puedo atender") separado de liveness ("sigo vivo"). La liveness no consulta dependencias externas.
- [ ] En Kubernetes, un `preStop` más largo que lo que tarda la red en sacarte de rotación (en GKE, kube-proxy sincroniza cada 10 s como mínimo: 5 s no alcanzan), y un `terminationGracePeriodSeconds` que cubra `preStop` + tu apagado. 📏
- [ ] Inicializa una sola vez y reutiliza: clientes HTTP, conexiones y modelos se crean al arrancar, no por request.
- [ ] El disco del contenedor es efímero: estado fuera, configuración por variables de entorno.
- [ ] Credenciales por defecto (ADC en Google Cloud, la cadena por defecto en AWS) y ninguna llave en el código ni en la imagen: la plataforma entrega la identidad.
- [ ] Conoce las reglas de tu plataforma: límites en Kubernetes, concurrencia y CPU solo durante el request en Cloud Run, nada en segundo plano después de responder en Lambda.

## 3. Aprovechar los núcleos

Tu proceso no sabe cuántos recursos tiene: díselo tú, y mídelo.

- [ ] Nunca calcules los workers con `os.cpu_count()` en un contenedor: ve los núcleos del nodo, no tu límite. Fíjalos por variable de entorno. 📏
- [ ] Desde Python 3.13, `PYTHON_CPU_COUNT` (o `-X cpu_count`) sobreescribe `os.cpu_count()` y `multiprocessing.cpu_count()`. En Kubernetes puedes tomarlo del límite del pod con la Downward API. 📏
- [ ] En Kubernetes, 1 proceso por contenedor y escala con réplicas.
- [ ] `workers × memoria por worker` tiene que caber en el límite. Mide el RSS. 📏
- [ ] `async def` solo si toda la cadena es async. Si llamas a un SDK síncrono, usa `def` o `asyncio.to_thread`. 📏
- [ ] Los endpoints `def` comparten un threadpool de 40 hilos por proceso (AnyIO); súbelo o usa async si tienes mucha concurrencia de I/O. 📏
- [ ] Un cliente HTTP por proceso, creado en el `lifespan`.
- [ ] Cada proceso abre su propio pool de conexiones: `workers × pods × tamaño del pool` tiene que caber en el `max_connections` de la base (asyncpg: 10 por defecto, 17 workers abren 170).
- [ ] Antes de producción, test de carga con tasa constante, no solo con usuarios concurrentes.

## 4. Lo que se logea

Cada línea se paga dos veces: en CPU al generarla y en dinero al guardarla.

- [ ] Formato perezoso (`log.debug("x=%s", x)`) y nada de objetos grandes en un log. 📏
- [ ] INFO o WARNING en producción, sin payloads completos.
- [ ] Sin duplicados: el access log en el balanceador o en la app, no en ambos. Excluye los health checks.
- [ ] Muestrea los logs de éxito de alto volumen y guarda el 100% de los errores.
- [ ] Logs estructurados (JSON) para consultar campos.
- [ ] Para contar cosas, métricas, no logs.
- [ ] Revisa el volumen de logs por servicio cada mes, con filtros de exclusión y retención al guardarlos.
