---
theme: none
title: Misma app, dos resultados distintos
author: Diego Parra
info: PyCon Chile 2026. Buenas prácticas para desplegar Python en contenedores.
colorSchema: light
aspectRatio: 16/9
canvasWidth: 1280
fonts:
  provider: none
highlighter: shiki
lineNumbers: false
transition: none
download: false
exportFilename: misma-app-dos-resultados-distintos
---


<div class="paquete" style="grid-template-columns:1fr">
  <div class="marca">
    <h1>Misma app,<br>dos resultados distintos</h1>
    <p>Buenas prácticas para desplegar Python en contenedores</p>
  </div>
  <div></div>
  <div class="pie"><span>PyCon Chile 2026</span><span class="muted">Online</span><span class="muted">Diego Parra</span></div>
</div>

<!--
(0:00, 0:45) Es la misma app dos veces, en un contenedor, con una diferencia: cómo está construida y cómo arranca.
Cuatro prácticas, cada una con el código malo, el bueno y los números. Dos demos en vivo y el resto medido en GKE y Podman.
-->

---

<div class="bandas">
  <h2>Una tienda. Un <code>app.py</code>.</h2>
  <div class="evidencia apilado">

```python
@app.post("/orders")
async def create_order(order: Order):
    total, order_id = order_total(order), uuid.uuid4()
    response = await app.state.payments.post(PAYMENTS_URL, json={...})
    response.raise_for_status()
    await app.state.db.execute("insert into orders ...", order_id, ...)
    return {"order_id": str(order_id), "total": total, ...}
```

  <div class="flujo">
    <table class="receta cifras compacta">
      <thead><tr><th></th><th>A: como en el tutorial</th><th>B: con las prácticas</th></tr></thead>
      <tbody>
        <tr><th>Base</th><td><code>python:3.13</code></td><td><code>3.13-slim</code></td></tr>
        <tr><th>Dependencias</th><td><code>pip</code>, después</td><td><code>uv.lock</code>, antes</td></tr>
        <tr><th>Arranque</th><td><code>CMD ./start.sh</code></td><td><code>CMD ["uvicorn", …]</code></td></tr>
        <tr><th>Procesos</th><td>17 workers</td><td>1</td></tr>
      </tbody>
    </table>
  </div>
  </div>
  <footer><Origen>app/app.py · FastAPI</Origen><Origen>deploy/bad/Dockerfile</Origen><Origen>deploy/good/Dockerfile</Origen></footer>
</div>

<style>
.compacta tbody th { font-size: 20px; padding: 4px 12px 4px 0; }
.compacta td { padding: 4px 12px 4px 0; font-size: 19px; }
</style>

<!--
(0:45, 1:30) La app es aburrida a propósito: catálogo y órdenes; cada orden cobra en un servicio de pagos y luego se guarda en PostgreSQL. Si el proceso muere entre el cobro y el insert, el cliente pagó y no tiene orden. Esa es la métrica: cobradas sin orden.
Dos imágenes con el mismo código: A es la del tutorial, B aplica cuatro prácticas. Una por una.
-->

---

<div class="bandas">
  <h2>1. Procesos según el contenedor, no la máquina</h2>
  <div class="evidencia apilado">

```python {2}
import multiprocessing
workers = multiprocessing.cpu_count() * 2 + 1
```

  <table class="receta cifras">
    <thead><tr><th>Entorno</th><th><code>os.cpu_count()</code></th><th>Workers</th><th>CPU real</th></tr></thead>
    <tbody>
      <tr><th>VM e2-standard-8, sin contenedor</th><td><span class="num">8</span></td><td><span class="num">17</span></td><td>8</td></tr>
      <tr><th>Pod GKE, límite de 1 CPU</th><td><span class="num">8</span></td><td><span class="num">17</span></td><td class="loss"><span class="num">1</span></td></tr>
      <tr><th>Cloud Run, 1 vCPU</th><td><span class="num">5–6</span></td><td class="loss"><span class="num">11–13</span></td><td class="loss"><span class="num">1</span></td></tr>
    </tbody>
  </table>
  <p class="chica">En la VM está bien: 550 rps sin errores, p95 212 ms.</p>
</div>
<footer><Origen>gunicorn.org/guides/docker</Origen><Origen>docs.python.org · os.cpu_count()</Origen><Origen>GCP · 15 nov · Cloud Run: 3 ejecuciones</Origen></footer>
</div>

<!--
(3:30, 2:00) Esta línea es la recomendación de la guía de Docker de gunicorn. En una VM es correcta.
Pero os.cpu_count() ve la máquina, no el límite: en un pod de 1 CPU salen 17 workers, y en Cloud Run 11 a 13.
Mismo código, tres resultados según dónde corre.
-->

---

<div class="bandas">
  <h2>1. Un proceso por contenedor, escalar con réplicas</h2>
  <div class="evidencia dos">
    <div class="arreglo">

```dockerfile
CMD ["uvicorn", "app:app", ...]
```

```sh
PYTHON_CPU_COUNT=1
```

<p class="chica">Sin <code>--workers</code>. Si necesitas varios: <code>PYTHON_CPU_COUNT=1</code> (Python 3.13).</p>
</div>
    <Tabla title="Por pod, 1 CPU" unit="GKE · 2 pods por versión" :rows="[
      { label: 'Memoria a 200 rps', a: '1.430 MiB', b: '95 MiB' },
      { label: 'Pico 550 rps: servidas', a: '~300/s', b: '550/s' },
      { label: 'Pico: p95', a: '> 5 s', b: '≈ 250 ms', loss: true },
      { label: 'CPU throttling', a: '100%', b: '0%' },
      { label: 'Conexiones a PostgreSQL', a: '170', b: '10' },
    ]" />
  </div>
  <footer><Origen>GKE · 11 y 15 nov · 3 corridas</Origen></footer>
</div>

<!--
(5:30, 2:30) La solución: un proceso por contenedor y escalar con réplicas. El CMD de B es uvicorn sin --workers.
Resultado a 1 CPU: 95 MiB contra 1.430 por pod, 170 conexiones a la base contra 10, y en el pico B sirve los 550 rps mientras A llega a ~300 con p95 sobre 5 s.
-->

---

<div class="demo vivo">
  <div class="cabecera">
    <h1>En vivo: el pico</h1>
    <p>De 200 a <strong>550 rps</strong> por versión, en las dos al mismo tiempo.</p>
  </div>
  <Arena />
  <div class="lateral">
    <Grafana :panel="6" title="Requests OK por segundo" />
    <Grafana :panel="10" title="CPU throttling" />
  </div>
</div>

<!--
(~3 min) Antes de la charla: `make proxy`, `make board`, `make load RATE=200 DURATION=60m` y en el tablero espacio (autoplay 20/s) y x x (reiniciar). Hacer: en otra terminal, `make load RATE=550 DURATION=3m` (reemplaza la carga base; al terminar volver a `make load RATE=200 DURATION=60m`).
Decir: miren los errores de A en el tablero y los de B no. En los paneles: A sirve ~300 rps con su CPU frenada al 100%; B sirve los 550. Prometheus va ~15 s atrasado.
Si el cluster no responde, los paneles muestran la captura del ensayo.
-->

<!--
(8:00, 3:00) Antes de la charla: `make proxy`, `make board`, `make load RATE=200 DURATION=60m` y en el tablero espacio (autoplay 20/s) y x x (reiniciar). Hacer: en otra terminal, `make load RATE=550 DURATION=3m` (al terminar volver a `make load RATE=200 DURATION=60m`).
Decir: miren los errores de A en el tablero y los de B no; A sirve ~300 rps con la CPU frenada al 100%, B sirve los 550.
Si el cluster no responde, los paneles muestran la captura del ensayo.
-->

---

<div class="bandas">
  <h2>2. Que la señal llegue al proceso</h2>
  <div class="evidencia dos">

```dockerfile {5}
FROM python:3.13
WORKDIR /app
COPY app/ deploy/bad/ ./
RUN pip install -r requirements.txt
CMD ./start.sh
```

```sh {3}
#!/bin/sh
echo "Starting shop..."
gunicorn -c gunicorn_conf.py app:app
```

  </div>
  <div class="lineas">
    <p>PID 1 es <code>sh</code>: SIGTERM no llega a gunicorn.</p>
    <p class="loss"><strong>La plataforma espera y mata con SIGKILL: las órdenes en curso quedan cobradas y no guardadas.</strong></p>
  </div>
  <footer><Origen>deploy/bad/Dockerfile</Origen><Origen>deploy/bad/start.sh</Origen><Origen>docs.docker.com · CMD en forma shell</Origen></footer>
</div>

<!--
(11:00, 1:30) Dos líneas inocentes: CMD en forma shell y un script que lanza gunicorn sin exec.
Docker lo dice: la forma shell no recibe señales. PID 1 es sh, el SIGTERM muere ahí, y a los 10 s la plataforma manda SIGKILL.
-->

---

<div class="bandas">
  <h2>2. Forma exec, o <code>exec</code> en el script</h2>
  <div class="evidencia dos">
    <div class="arreglo">

```dockerfile
CMD ["uvicorn", "app:app", ...]
```

```sh {2}
#!/bin/sh
exec gunicorn -c gunicorn_conf.py app:app
```

</div>
<Tabla title="Detener una réplica" unit="A contra B" :rows="[
      { label: 'Apagado', a: '10,3 s · exit 137', b: '0,5 s · exit 0' },
      { label: 'Rollout de 2 réplicas', a: '43–47 s', b: '8–12 s' },
      { label: 'Cobradas sin orden por deploy', a: '26–30', b: '0', loss: true },
    ]" />
  </div>
  <footer><Origen>Apagado: Podman · 15 nov · 5 corridas</Origen><Origen>Rollout: GKE · 15 nov · 3 corridas</Origen><Origen>Cobradas, 200 órdenes/s: GKE · 11 nov · 3 corridas</Origen></footer>
</div>

<!--
(12:30, 2:30) Con la forma exec, uvicorn es PID 1 y recibe SIGTERM. En el script, exec reemplaza sh por gunicorn.
Apagado: 10,3 s y exit 137 contra 0,5 s y exit 0. El rollout de 2 réplicas baja de 43–47 s a 8–12 s.
Y a 200 órdenes/s, cada deploy de A deja 26–30 cobradas sin orden; B, 0.
-->

---

<div class="demo vivo">
  <div class="cabecera">
    <h1>En vivo: un deploy</h1>
    <p>Desplegamos las dos versiones con carga. Miren <strong>cobradas sin orden</strong>.</p>
  </div>
  <Arena />
  <div class="lateral">
    <Grafana :panel="7" title="Errores por segundo" />
    <Grafana :panel="13" title="Réplicas listas" />
  </div>
</div>

<!--
(~3 min) Hacer: en el tablero x x para reiniciar los contadores; luego, con la carga base de 200 rps, `make rollout`. En el ensayo: B en ~10 s, A en ~33 s, A 14 cobradas sin orden y B 0.
Decir: B termina en ~10 s; A tarda ~45 s y, cuando la plataforma la mata con SIGKILL, pierde órdenes ya cobradas. Mostrar el contador de cobradas sin orden de cada versión en el tablero.
Si el cluster no responde, los paneles muestran la captura del ensayo.
-->

<!--
(15:00, 3:00) Hacer: en el tablero x x para reiniciar los contadores; luego, con la carga base de 200 rps, `make rollout`. En el ensayo: B en ~10 s, A en ~33 s, A 14 cobradas sin orden y B 0.
Decir: miren cobradas sin orden de cada versión; A pierde órdenes cuando la plataforma la mata con SIGKILL.
Si el cluster no responde, los paneles muestran la captura del ensayo.
-->

---

<div class="bandas">
  <h2>3. Dependencias antes que el código, con lockfile</h2>
  <div class="evidencia">

```dockerfile {3,4}
FROM python:3.13
WORKDIR /app
COPY app/ deploy/bad/ ./
RUN pip install -r requirements.txt
```

  <div class="flujo">
    <p class="loss"><strong>Cada cambio de código invalida la capa de dependencias.</strong></p>
    <p>Una línea de <code>app.py</code> reinstala todo.</p>
  </div>
</div>
<footer><Origen>deploy/bad/Dockerfile</Origen><Origen>docs.docker.com/build/cache/optimize</Origen></footer>
</div>

<!--
(18:00, 1:30) A copia todo el código y recién después instala. Cambiar una línea de app.py invalida la capa del pip install y se reinstalan las dependencias.
La documentación de Docker lo dice: lo que cambia seguido va al final.
-->

---

<div class="bandas">
  <h2>3. Lockfile primero, código al final</h2>
  <div class="evidencia dos">

```dockerfile {2,3,6}
WORKDIR /app
COPY app/pyproject.toml app/uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project
# ... etapa final
COPY --from=build /app/.venv .venv
COPY app/app.py ./
```

  <div class="arreglo">
    <Tabla title="Tras cambiar 1 línea" unit="A contra B" :rows="[
      { label: 'Rebuild', a: '20–21 s', b: '3,5 s' },
      { label: 'Capas nuevas por cambio', a: '311 MB', b: '0,01 MB' },
      { label: 'Cloud Build, sin caché', a: '79 s', b: '82 s', loss: true },
    ]" />
    <p class="chica">Sin caché en el CI, el orden de capas no ayuda.</p>
  </div>
</div>
<footer><Origen>Rebuild: Podman · 15 nov · 5 corridas</Origen><Origen>Capas nuevas: Podman · 11 nov</Origen><Origen>Cloud Build · 15 nov · 1 corrida</Origen></footer>
</div>

<!--
(19:30, 2:00) B copia solo pyproject y uv.lock, instala con --frozen y deja app.py para la última capa.
Rebuild tras cambiar una línea: 20 s contra 3,5 s. Capas nuevas: 311 MB contra 0,01 MB.
Ojo: en Cloud Build sin caché da igual, 79 contra 82 s. Si su CI no guarda capas, esto no ayuda.
-->

---

<div class="demo">
  <div class="cifra">DEMO</div>
  <div>
    <h1>Builds lentos</h1>
    <p>Cambiamos una línea de <code>app.py</code> y reconstruimos A y B.</p>
    <p class="aviso"><code>scripts/demo.sh build</code></p>
  </div>
</div>

<!--
(3:30, 2:30) Hacer: `scripts/demo.sh build` (con `make local` ya levantado y las dos imágenes construidas una vez, cache caliente). Imprime el `time` de A y luego el de B, y revierte el cambio solo.
Señalar: A ~20 s (repite pip install porque el código se copia antes de las dependencias); B ~3,5 s (solo cambia la última capa). Preguntar: ¿cuántas veces por día corre su CI? Multiplicar la diferencia por esa cifra.
Si el build tarda por la red, dejar correr y hablar del slide siguiente; los números ya están medidos.
-->

<!--
(21:30, 2:00) Hacer: `scripts/demo.sh build` (con `make local` ya levantado y las dos imágenes construidas una vez, cache caliente). Imprime el `time` de A y luego el de B, y revierte el cambio solo.
Señalar: A ~20 s (repite pip install); B ~3,5 s (solo cambia la última capa).
Si el build tarda por la red, dejar correr y seguir; los números ya están medidos.
-->

---

<div class="bandas">
  <h2>4. Imagen slim y multi-stage</h2>
  <div class="evidencia">

```dockerfile {1}
FROM python:3.13
```

  <div class="flujo">
    <p class="loss"><strong>Cada nodo nuevo baja la imagen antes de arrancar.</strong></p>
    <p>El autoescalado espera.</p>
  </div>
</div>
<footer><Origen>deploy/bad/Dockerfile</Origen></footer>
</div>

<!--
(23:30, 1:30) La imagen completa trae compiladores y herramientas que la app no usa en runtime.
Cuando el autoscaler agrega un nodo, el pull ocurre antes de que arranque la réplica: el tráfico espera.
-->

---

<div class="bandas">
  <h2>4. Dos etapas sobre <code>slim</code></h2>
  <div class="evidencia dos">

```dockerfile {1,4}
FROM python:3.13-slim AS build
# ... uv sync

FROM python:3.13-slim
RUN useradd --system --uid 1000 app
WORKDIR /app
COPY --from=build /app/.venv .venv
```

  <Tabla title="Imagen y nodo frío" unit="A contra B" :rows="[
    { label: 'Imagen', a: '1,46 GB', b: '392 MB' },
    { label: 'Pull en nodo frío', a: '21,4 s', b: '7,0 s' },
    { label: 'Réplica nueva, hasta Ready', a: '39–45 s', b: '13 s', loss: true },
    { label: 'Vulnerabilidades conocidas', a: '4.265', b: '212' },
  ]" />
</div>
<footer><Origen>GKE · 15 nov · pull y nodo frío</Origen><Origen>Trivy 0.76.2</Origen></footer>
</div>

<!--
(25:00, 2:00) B usa dos etapas sobre slim: se instala en una, y solo el .venv pasa a la imagen final.
1,46 GB contra 392 MB; el pull en un nodo frío baja de 21 a 7 s, y la réplica nueva queda Ready en 13 s en vez de 39–45.
Trivy: 4.265 vulnerabilidades conocidas contra 212.
-->

---

<div class="bandas">
  <h2>Además, cuatro líneas</h2>
  <div class="evidencia dos" style="display:grid;grid-template-columns:1fr 1fr;gap:20px 24px;align-items:start">

```dockerfile
ARG UV_COMPILE_BYTECODE=1
```

```dockerfile
USER 1000
```

```dockerfile
ENV PYTHONUNBUFFERED=1
```

```text
# .dockerignore
*
!app/
!deploy/
```

  </div>
  <div class="lineas">
    <p><strong>Bytecode:</strong> arranque 0,9 s contra 1,6 s sin él.</p>
    <p>Sin root · logs sin buffer · <code>.dockerignore</code> como lista blanca.</p>
  </div>
  <footer><Origen>Arranque: Podman · 11 nov</Origen><Origen>deploy/good/Dockerfile</Origen></footer>
</div>

<!--
(27:00, 1:00) Cuatro líneas más, rápido: bytecode compilado en el build (arranque 0,9 s contra 1,6 s), usuario no root, logs sin buffer, y un .dockerignore que parte en * y deja pasar solo app/ y deploy/.
-->

---

<div class="bandas resumen">
  <h2>Resumen y para el lunes</h2>
  <div class="evidencia">
    <Tabla title="A contra B" unit="1 CPU por contenedor" :rows="[
      { label: 'Memoria por pod', a: '1.430 MiB', b: '95 MiB' },
      { label: 'Pico de 550 rps, servidas', a: '~300/s', b: '550/s', loss: true },
      { label: 'Apagado', a: '10,3 s', b: '0,5 s' },
      { label: 'Cobradas sin orden por deploy', a: '26–30', b: '0', loss: true },
      { label: 'Rebuild, 1 línea', a: '20–21 s', b: '3,5 s' },
      { label: 'Imagen', a: '1,46 GB', b: '392 MB' },
      { label: 'Réplica nueva, nodo frío', a: '39–45 s', b: '13 s' },
    ]" />
    <ol class="preparacion">
      <li>Un proceso por contenedor; escala con réplicas.</li>
      <li><code>exec</code>: CMD en forma exec o <code>exec</code> en el script.</li>
      <li>Lockfile y dependencias antes del código.</li>
      <li>Base <code>slim</code> y multi-stage.</li>
    </ol>
  </div>
  <footer><Origen>GKE · 11 y 15 nov</Origen><Origen>Podman · 15 nov</Origen></footer>
</div>

<!--
(28:00, 2:00) Cierre. Cuatro prácticas, cuatro causas: dónde corre tu app, cómo la apaga la plataforma, cómo ordenas las capas y cuánto pesa lo que despliegas.
Para el lunes, una acción por práctica. El repo tiene los scripts para reproducir cada número. Preguntas.
-->
