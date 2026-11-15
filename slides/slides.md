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
  <div class="sellos">
    <Seal word="memoria" :size="190" />
    <Seal word="baja disponibilidad" :size="190" />
    <Seal word="reinicios" :size="190" />
    <Seal word="latencia" :size="190" />
  </div>
  <div class="pie"><span>PyCon Chile 2026</span><span class="muted">Online</span><span class="muted">Diego Parra</span></div>
</div>

<!--
(0:00) La misma app, empaquetada dos veces. Mismo código Python, mismos recursos, mismo manifiesto de Kubernetes. Cambia cómo se construye la imagen y cómo arranca el proceso.
-->

---
layout: none
---

<div class="meme"><img src="/tulio-cola.jpg" alt="Lata de Tulio Cola de 31 Minutos llena de sellos ALTO EN"></div>

<style>
.meme { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; background: #f6b800; }
.meme img { height: 100%; width: auto; object-fit: contain; }
</style>

<!--
(0:30) El meme. Así se ve la versión A después de esta charla: cumple, pero con todos los sellos.
-->

---

<div class="bandas">
  <h2>Cinco cosas</h2>
  <ol class="preparacion cinco">
    <li>Cuántas CPUs ve tu app</li>
    <li>Réplicas, no <code>--workers</code></li>
    <li>Que la señal llegue al proceso</li>
    <li>Dependencias antes que el código</li>
    <li>Imagen <code>slim</code> y multi-stage</li>
  </ol>
</div>

<style>
.cinco li { font-size: 38px; padding: 14px 0 14px 72px; }
.cinco li::before { font-size: 44px; top: 14px; }
</style>

<!--
(0:45) De esto vengo a hablar: cinco cosas. Cada una con el código de antes, el de después y lo que medimos.
-->

---

<div class="bandas">
  <h2>Una tienda. Un <code>app.py</code>.</h2>
  <div class="evidencia apilado">

```python
@app.post("/orders")
async def create_order(order: Order):
    response = await app.state.payments.post(...)  # cobra
    await app.state.db.execute("insert into orders ...")  # guarda
```

  <table class="receta cifras">
    <thead><tr><th></th><th>A: el tutorial</th><th>B: las prácticas</th></tr></thead>
    <tbody>
      <tr><th>Base</th><td><code>python:3.13</code></td><td><code>3.13-slim</code></td></tr>
      <tr><th>Dependencias</th><td>después del código</td><td>antes del código, con lockfile</td></tr>
      <tr><th>Arranque</th><td><code>CMD ./start.sh</code></td><td><code>CMD ["uvicorn", …]</code></td></tr>
      <tr><th>Procesos</th><td>gunicorn, <code>cpu_count()*2+1</code></td><td>1</td></tr>
    </tbody>
  </table>
  </div>
  <footer><Origen>app/app.py</Origen><Origen>deploy/bad · deploy/good</Origen></footer>
</div>

<!--
(1:30) La app: catálogo y órdenes. Cada orden cobra en un servicio de pagos y después se guarda en PostgreSQL. Si el proceso muere entre las dos líneas, el cliente pagó y no tiene orden.
A es como en muchos tutoriales. B aplica las cinco cosas. Corren en GKE, 2 pods de 1 CPU y 2 GiB cada una, en nodos iguales.
-->

---

<div class="bandas">
  <h2>Mismo manifiesto, mismos recursos</h2>
  <div class="evidencia dos">

```yaml {2,7-8}
name: bad
image: …/bad
replicas: 2
terminationGracePeriodSeconds: 40
resources:
  requests: {cpu: "1", memory: 2Gi}
  limits:   {cpu: "1", memory: 2Gi}
readinessProbe: {httpGet: {path: /health}}
preStop: {sleep: {seconds: 15}}
```

```yaml {2,7-8}
name: good
image: …/good
replicas: 2
terminationGracePeriodSeconds: 40
resources:
  requests: {cpu: "1", memory: 2Gi}
  limits:   {cpu: "1", memory: 2Gi}
readinessProbe: {httpGet: {path: /health}}
preStop: {sleep: {seconds: 15}}
```

  </div>
  <footer><Origen>k8s/demo.yaml · resumido</Origen><Origen>GKE · nodos n2-standard-8 idénticos, uno por versión</Origen></footer>
</div>

<!--
(2:15) Las dos versiones corren con el mismo Deployment: 2 réplicas, 1 CPU y 2 GiB por pod, el mismo readiness probe, el mismo preStop y el mismo plazo de apagado. Cada versión en su propio nodo, de la misma máquina y la misma CPU. Lo único que cambia es la imagen.
-->

---

<div class="bandas">
  <h2>1. ¿Cuántas CPUs ve tu app?</h2>
  <div class="evidencia apilado">

```python
workers = multiprocessing.cpu_count() * 2 + 1   # gunicorn.org/guides/docker
```

  <table class="receta cifras">
    <thead><tr><th>Dónde corre</th><th><code>os.cpu_count()</code></th><th>Workers</th><th>CPU real</th></tr></thead>
    <tbody>
      <tr><th>VM de 8 vCPU</th><td><span class="num">8</span></td><td><span class="num">17</span></td><td><span class="num">8</span></td></tr>
      <tr><th>Pod en esa misma máquina, límite de 1 CPU</th><td><span class="num">8</span></td><td><span class="num">17</span></td><td class="loss"><span class="num">1</span></td></tr>
      <tr><th>Cloud Run, 1 vCPU</th><td><span class="num">5–6</span></td><td class="loss"><span class="num">11–13</span></td><td class="loss"><span class="num">1</span></td></tr>
    </tbody>
  </table>
  </div>
  <footer><Origen>GCP · 15 nov</Origen><Origen>gunicorn.org/guides/docker</Origen><Origen>docs.python.org/3/library/os.html#os.cpu_count</Origen></footer>
</div>

<!--
(3:00) Situación: la guía de Docker de gunicorn recomienda esta línea. En una VM es correcta: 8 núcleos, 17 workers, y con la misma config A sirvió 550 rps sin errores.
Problema: os.cpu_count() ve la máquina, no el límite del contenedor. En el pod con 1 CPU salen 17 workers para 1 CPU; en Cloud Run vimos 6, 6 y 5 en tres ejecuciones.
Solución: cuenta desde el límite. Un proceso por contenedor, o PYTHON_CPU_COUNT=1 desde Python 3.13. Aislado: con solo ese cambio (1 worker), A baja a 112 MiB y sirve los 550 rps.
-->

---

<div class="bandas">
  <h2>1. Misma carga, 15 veces la memoria</h2>
  <div class="evidencia dos">
    <img class="grafico" src="/charts/memory.svg" alt="Memoria por pod de A y B con la misma carga">
    <Tabla title="Por pod, 1 CPU" unit="200 rps por versión" :rows="[
      { label: 'Memoria', a: '1.430 MiB', b: '95 MiB', loss: true },
      { label: 'Procesos', a: '18', b: '1' },
      { label: 'Conexiones a PostgreSQL', a: '170', b: '10' },
    ]" />
  </div>
  <footer><Origen>GKE · 11 y 15 nov · 3 corridas</Origen><Origen>docs.python.org/3/using/cmdline.html · PYTHON_CPU_COUNT</Origen></footer>
</div>

<!--
(5:00) Con la misma carga, A usa 1.430 MiB por pod y B 95. Cada worker carga la app entera y abre su propio pool de conexiones: 170 conexiones a la base por pod contra 10.
Las dos tienen el mismo límite, 2 GiB: a A le alcanza, pero gasta 15 veces más. En Kubernetes eso es memoria que reservas y pagas, y conexiones que se acaban: en local, tres copias de A agotaron max_connections de PostgreSQL.
-->

---

<div class="bandas">
  <h2>1. ¿Y si igualamos la memoria a lo que usa B?</h2>
  <div class="evidencia dos">

```yaml
limits: {cpu: "1", memory: 200Mi}
```

  <Tabla title="Límite de 200 MiB para las dos" unit="200 rps por versión" :rows="[
    { label: '¿Arranca?', a: 'No: OOMKilled', b: 'Sí', loss: true },
    { label: 'Estado', a: 'CrashLoopBackOff', b: 'Running' },
    { label: 'Memoria usada', a: '—', b: '94 MiB' },
    { label: 'Errores en 90 s', a: '14.100', b: '0', loss: true },
  ]" />
  </div>
  <footer><Origen>GKE · 15 nov · 1 corrida</Origen><Origen>kubernetes.io · OOMKilled al pasar el límite de memoria</Origen></footer>
</div>

<!--
(6:00) ¿Y si a A le damos lo mismo que necesita B? 200 MiB para las dos. A no llega a arrancar: mientras levanta sus workers pasa el límite, el kernel la mata (OOMKilled, exit 137) y Kubernetes la reinicia en bucle. Alcanza a levantar 13 de 17 workers. B sigue en 94 MiB con cero errores.
Detalle bueno para contar: al cambiar el límite, Kubernetes no tiró el servicio. El pod nuevo de A nunca quedó listo, así que el rollout se trabó y dejó corriendo los viejos. En un primer deploy, sin versión anterior, A habría quedado caída.
-->

---

<div class="bandas">
  <h2>1. Y en un peak de 550 rps</h2>
  <div class="evidencia dos">
    <img class="grafico" src="/charts/served.svg" alt="Requests OK por segundo de A y B durante el peak">
    <Tabla title="Peak de 550 rps" unit="1 CPU por pod" :rows="[
      { label: 'Servidas', a: '~300/s', b: '550/s', loss: true },
      { label: 'p95', a: '> 5 s', b: '≈ 250 ms' },
      { label: 'CPU frenada (throttling)', a: '100%', b: '0%' },
      { label: 'CPU por request servida', a: '5,5 ms', b: '2,6 ms' },
    ]" />
  </div>
  <footer><Origen>GKE · 15 nov · nodos n2 idénticos</Origen><Origen>kubernetes.io/docs/concepts/configuration/manage-resources-containers</Origen></footer>
</div>

<!--
(7:30) Con carga normal, cada request cuesta casi lo mismo en A y en B: 3,2 contra 2,9 ms de CPU. En el peak no. Los 17 workers de A compiten por 1 CPU: el kernel salta de uno a otro, y la cuota de CPU (100 ms cada 100 ms) se agota antes de cada período, así que el contenedor entero queda congelado hasta el siguiente: throttling en el 100% de los períodos. Las requests se encolan, llegan al timeout de 5 s y esa CPU se pierde: A gasta 5,5 ms por request que sí sale, B 2,6. A cae a ~300 de 550; B sirve las 550 con p95 de 250 ms, usando 1,4 de sus 2 CPUs.
-->

---

<div class="bandas">
  <h2>2. Réplicas, no <code>--workers</code></h2>
  <div class="evidencia dos">
    <img class="grafico" src="/charts/ramp.svg" alt="Rampa de carga: 2 pods de 1 proceso contra 1 pod de 2 workers">
    <div class="lineas">
      <p>Mismas 2 CPUs: <strong>715 contra 692 rps</strong>, <strong>269 contra 297 MiB</strong>. En rendimiento, empate.</p>
      <p>La diferencia es operativa: Kubernetes escala, revisa y despliega por pod.</p>
    </div>
  </div>
  <footer><Origen>GKE · 15 nov · rampa de 100 a 1.000 rps · 1 corrida</Origen><Origen>fastapi.tiangolo.com/deployment/docker</Origen><Origen>kubernetes.io · Horizontal Pod Autoscaling</Origen></footer>
</div>

<!--
(8:30) Si necesito más capacidad, ¿más workers o más réplicas? Medimos las mismas 2 CPUs: 2 pods de 1 proceso contra 1 pod con --workers 2. Empate: 715 contra 692 rps y memoria parecida.
Entonces, ¿por qué réplicas? Porque la plataforma ya hace el trabajo del process manager: el autoscaler agrega pods, y los requests de CPU, el readiness, los rollouts y las caídas funcionan por pod.
-->

---

<div class="bandas">
  <h2>3. Que la señal llegue al proceso</h2>
  <div class="evidencia dos">

```dockerfile
CMD ./start.sh
```

```sh {3}
#!/bin/sh
echo "Starting shop..."
gunicorn -c gunicorn_conf.py app:app
```

  <div class="lineas">
    <p>PID 1 es <code>sh</code>. El SIGTERM muere ahí.</p>
    <p class="loss"><strong>La plataforma espera y mata con SIGKILL, con órdenes a medio camino.</strong></p>
  </div>
  </div>
  <footer><Origen>docs.docker.com/reference/dockerfile · shell and exec form</Origen><Origen>kubernetes.io · Pod lifecycle, termination</Origen></footer>
</div>

<!--
(11:30) Situación: CMD en forma shell y un script que lanza gunicorn sin exec. Muy común.
Problema: el proceso 1 es sh, que no reenvía señales. En cada deploy o escalado hacia abajo, la plataforma manda SIGTERM, nadie lo atiende, espera su plazo y mata con SIGKILL. Lo que estaba en curso se pierde.
-->

---

<div class="bandas">
  <h2>3. Forma exec, o <code>exec</code> en el script</h2>
  <div class="evidencia dos">
    <div class="arreglo">

```dockerfile
CMD ["uvicorn", "app:app", "--host", "0.0.0.0"]
```

```sh
exec gunicorn -c gunicorn_conf.py app:app
```

</div>
    <Tabla title="Apagar y desplegar" unit="A contra B" :rows="[
      { label: 'Apagado', a: '10,3 s · exit 137', b: '0,5 s · exit 0' },
      { label: 'Cobradas sin orden, por deploy', a: '26–30', b: '0', loss: true },
      { label: 'Solo el exec, 1 worker en los dos', a: '26', b: '0' },
    ]" />
  </div>
  <footer><Origen>Apagado: Podman · 15 nov</Origen><Origen>Cobros: GKE · 11 nov · 3 corridas; solo exec: 1 corrida</Origen><Origen>docs.docker.com/reference/cli/docker/container/stop</Origen></footer>
</div>

<!--
(13:00) Solución: CMD en forma exec, o exec en el script. Ahora el servidor es el proceso 1 y recibe SIGTERM: termina lo que tiene y sale.
Apagado de 10 s con SIGKILL a medio segundo. Con 200 órdenes por segundo, cada deploy de A deja 26 a 30 clientes cobrados sin orden; B, cero. Y es el exec: con 1 worker en las dos versiones, sin exec quedan 26; con exec, 0.
-->

---

<div class="bandas">
  <h2>4. Dependencias antes que el código</h2>
  <div class="evidencia dos">

```dockerfile {3,4}
FROM python:3.13
WORKDIR /app
COPY app/ deploy/bad/ ./
RUN pip install -r requirements.txt
```

```dockerfile {1,2,4}
COPY app/pyproject.toml app/uv.lock ./
RUN uv sync --frozen --no-install-project
# ...
COPY app/app.py ./
```

  </div>
  <footer><Origen>docs.docker.com/build/cache/optimize</Origen><Origen>docs.astral.sh/uv/guides/integration/docker</Origen></footer>
</div>

<!--
(15:30) Situación: A copia todo el código y después instala. Problema: cambiar una línea de app.py invalida la capa de pip install y reinstala todo.
Solución: copiar solo el lockfile, instalar, y dejar el código para la última capa. Lo que cambia seguido va al final.
No es pip contra uv: con pip es igual, requirements.txt primero (idealmente con hashes y --require-hashes), pip install --no-cache-dir, y el código al final. uv suma velocidad y --frozen, que instala exactamente el lockfile sin resolver de nuevo; en B se copia su binario desde la imagen oficial, fijado a una versión, y no queda en la imagen final.
-->

---

<div class="demo">
  <div class="cifra">DEMO</div>
  <div>
    <h1>Una línea de código, dos builds</h1>
    <p class="aviso"><code>scripts/demo.sh build</code></p>
  </div>
</div>

<!--
(17:00) Hacer: `scripts/demo.sh build` (con `make local` arriba y la caché caliente). Cambia una línea de app.py, construye A y B con time y revierte el cambio.
Señalar: A ~20 s, reinstala dependencias; B ~3,5 s, solo la última capa.
-->

---

<div class="bandas">
  <h2>4. Lo que cuesta cada cambio</h2>
  <Tabla title="Tras cambiar 1 línea" unit="A contra B" :rows="[
    { label: 'Rebuild local, cada cambio', a: '20–21 s', b: '3,5 s' },
    { label: 'Capas nuevas que subir al registry', a: '311 MB', b: '0,01 MB', loss: true },
    { label: 'Cloud Build sin caché', a: '79 s', b: '82 s' },
  ]" />
  <p class="chica">Sin caché en el CI, el orden de las capas no ayuda: guarda la caché.</p>
  <footer><Origen>Podman · 11 y 15 nov · 5 corridas</Origen><Origen>Cloud Build · 15 nov</Origen></footer>
</div>

<!--
(19:00) Esto se siente primero en tu máquina: cada vez que cambias código y reconstruyes para probar, 20 s contra 3,5 s. En un día de iteración local son minutos perdidos por persona. Y en el registry: 311 MB nuevos que subir al registry y bajar en cada nodo, contra 10 KB.
Ojo: en Cloud Build sin caché da igual, 79 contra 82 s. El orden de capas solo sirve si el CI conserva la caché.
-->

---

<div class="bandas">
  <h2>5. Imagen <code>slim</code> y multi-stage</h2>
  <div class="evidencia dos">

```dockerfile {1,4,5}
FROM python:3.13-slim AS build
RUN uv sync --frozen ...

FROM python:3.13-slim
COPY --from=build /app/.venv .venv
```

  <Tabla title="Imagen y autoescalado" unit="A contra B" :rows="[
    { label: 'Imagen', a: '1,46 GB', b: '392 MB' },
    { label: 'Pull en un nodo nuevo', a: '21,4 s', b: '7,0 s', loss: true },
    { label: 'Vulnerabilidades conocidas', a: '4.265', b: '212' },
  ]" />
  </div>
  <footer><Origen>GKE · 15 nov · nodo nuevo</Origen><Origen>Trivy 0.76.2</Origen><Origen>docs.docker.com/build/building/best-practices · multi-stage</Origen></footer>
</div>

<!--
(20:30) Situación: FROM python:3.13, con compiladores y herramientas que la app no usa. Problema: cuando el autoscaler agrega un nodo, la réplica nueva primero baja la imagen.
Solución: instalar en una etapa y copiar solo el .venv a una imagen slim. 1,46 GB contra 392 MB: el pull en un nodo nuevo baja de 21 a 7 s, y la réplica nueva empieza a arrancar antes. De paso, 4.265 vulnerabilidades conocidas contra 212.
-->

---

<div class="bandas">
  <h2>Sé consciente de dónde corre tu código</h2>
  <div class="evidencia">
    <ol class="preparacion cierre">
      <li>Cuenta las CPUs del contenedor, no de la máquina. <span class="muted">1.430 → 95 MiB</span></li>
      <li>Escala con réplicas; la plataforma ya es tu process manager.</li>
      <li><code>exec</code>: que el SIGTERM llegue. <span class="muted">26–30 → 0 cobradas sin orden</span></li>
      <li>Lockfile primero, código al final. <span class="muted">20 → 3,5 s</span></li>
      <li><code>slim</code> y multi-stage. <span class="muted">pull 21 → 7 s</span></li>
    </ol>
  </div>
  <footer><Origen>github.com/0bCdian/pyconcl-2026-demo · cada número tiene su script</Origen></footer>
</div>

<!--
(23:30) La misma línea de código se comporta distinto en una VM, en un pod con límite y en Cloud Run. Las cinco cosas salen de una pregunta: dónde corre mi código y qué le pide esa plataforma.
El repo tiene los scripts para reproducir cada número. Preguntas.
-->
