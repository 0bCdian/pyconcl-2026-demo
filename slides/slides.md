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

<div class="paquete">
  <div class="marca">
    <h1>Misma app,<br>dos resultados distintos</h1>
    <p>Buenas prácticas para desplegar Python en contenedores</p>
  </div>
  <div class="sellos">
    <Seal word="memoria" :size="190" />
    <Seal word="workers" :size="190" />
    <Seal word="pérdidas" :size="190" />
  </div>
  <div class="pie"><span>PyCon Chile 2026</span><span class="muted">14 de noviembre · Santiago</span><span class="muted">Diego Parra</span></div>
  <div class="lado">
    <Tabla unit="Misma carga, mismos recursos" :rows="[
      { label: 'Memoria por pod', a: '1.375 MiB', b: '90 MiB' },
      { label: 'Workers por pod', a: '17', b: '1' },
      { label: 'Cobradas sin orden, por deploy', a: '24–30', b: '0', loss: true },
      { label: 'Imagen', a: '1,46 GB', b: '392 MB' },
    ]" origin="GKE · 2 pods de 1 CPU y 2 GiB por versión · imagen: Podman" />
    <Qr target="arena" label="Escanea y compra" :size="124" />
  </div>
</div>

<!--
(0:00) Esto es lo mismo, dos veces: una app en un contenedor, desplegada de dos maneras. Vamos a mirar qué cambia y a mostrar la evidencia.
La tabla es el resumen de toda la charla. Si el QR ya funciona, que lo escaneen ahora.
-->

---

<div class="bandas">
  <h2>Una tienda. Un <code>app.py</code>.</h2>
  <div class="evidencia">

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
    <p><strong>Catálogo</strong> con pandas, leído de un bucket.</p>
    <p><strong>Órdenes</strong> que cobran en un servicio de pagos (~150 ms) y se guardan en PostgreSQL.</p>
  </div>
  </div>
  <footer><Origen>app/app.py · FastAPI</Origen></footer>
</div>

<!--
(0:45) La app es aburrida a propósito: cobra y guarda la orden. Si el cobro funciona y la orden no se guarda, el cliente pagó y no tiene nada. Eso lo vamos a ver.
-->

---

<div class="bandas">
  <h2>Lo único que cambia es el envase</h2>
  <div class="evidencia envases">
    <div class="ingredientes">
      <b>Versión A</b>
      <code>python:3.13</code> completa, <code>pip install</code>, <code>CMD ./start.sh</code> en forma shell, un <code>start.sh</code> sin <code>exec</code>, gunicorn con <code>cpu_count() * 2 + 1</code> workers y corre como root.
    </div>
    <div class="ingredientes">
      <b>Versión B</b>
      <code>python:3.13-slim</code> en dos etapas, <code>uv sync --frozen</code> con bytecode precompilado, <code>CMD ["uvicorn", …]</code> en forma exec, un proceso y <code>USER 1000</code>.
    </div>
  </div>
  <footer><Origen>deploy/bad/Dockerfile</Origen><Origen>deploy/good/Dockerfile</Origen></footer>
</div>

<!--
(1:45) Esto es todo lo que cambia. El A es el Dockerfile que sale de cualquier tutorial. Nada de esto rompe un test ni un linter.
-->

---

<div class="bandas">
  <h2>Las reglas del ensayo</h2>
  <div class="evidencia">
    <dl class="reglas">
      <div><dt>Mismo código</dt><dd>El mismo <code>app.py</code> en las dos imágenes.</dd></div>
      <div><dt>Mismo manifiesto</dt><dd>Los dos Deployments solo difieren en el nombre, la imagen y el nodo.</dd></div>
      <div><dt>Mismos recursos</dt><dd>2 pods de 1 CPU y 2 GiB, un nodo <code>e2-standard-8</code> por versión.</dd></div>
      <div><dt>Misma carga</dt><dd>k6 a tasa constante contra las dos al mismo tiempo.</dd></div>
    </dl>
  </div>
  <footer><Origen>GKE · make up</Origen></footer>
</div>

<!--
(2:30) Si una comparación no es justa, no sirve. Todo lo que van a ver se reproduce con los scripts del repo.
-->

---

<div class="demo">
  <Qr target="arena" :size="380" />
  <div>
    <h1>Saquen el celular</h1>
    <p>Toquen <strong>COMPRAR</strong>. Cada toque es una orden real, la misma para A y para B.</p>
    <p class="aviso">La arena queda abierta toda la charla. Habrá dos eventos: un pico de tráfico y un deploy.</p>
  </div>
</div>

<!--
(3:15) Que escaneen y compren. Esta sesión sigue abierta hasta el final; no se cierra entre eventos.
Hacer: tener `make load RATE=200` corriendo de fondo y la pantalla de la arena (/screen) cargada. Seguir cuando los dos tableros vayan parejos: en un día tranquilo, A y B son idénticas.
-->

---

<div class="bandas">
  <h2>1. Workers según la CPU del contenedor</h2>
  <div class="evidencia">

```console
$ kubectl exec deploy/bad -- python -c "import os; print(os.cpu_count())"
8
$ kubectl exec deploy/bad -- cat /sys/fs/cgroup/cpu.max
100000 100000
```

  <div class="consecuencia">
    <p><code>os.cpu_count()</code> ve los 8 núcleos del nodo. El límite real es 1 CPU.</p>
    <p class="cuenta">8 × 2 + 1 = <strong>17 workers</strong> en 1 CPU</p>
    <div class="par"><Seal word="workers" :size="132" class="stamp" v-click /><Seal word="memoria" :size="132" class="stamp" v-click /></div>
  </div>
  </div>
  <footer><Origen>Pod de la versión A en GKE · Python 3.13</Origen></footer>
</div>

<!--
(4:15) Primer síntoma: memoria y throttling. Dentro del contenedor, os.cpu_count() ve el nodo, no la cuota. El límite vive en cgroups: cpu.max = 100 ms cada 100 ms, o sea 1 CPU. gunicorn calcula 2n+1 con n = 8.
-->

---

<div class="bandas">
  <h2>17 procesos en 1 CPU se pisan</h2>
  <div class="evidencia dos">
    <Tabla title="Por pod" unit="200 rps por versión" :rows="[
      { label: 'Memoria', a: '1.375 MiB', b: '90 MiB' },
      { label: 'Procesos', a: '17', b: '1' },
      { label: 'Hilos', a: '144', b: '12' },
      { label: 'Períodos de CPU frenados a 550 rps', a: '100%', b: '4–9%' },
    ]" />
    <div class="grafico">
      <Rampa :xmax="600" />
      <p class="muted">Órdenes servidas por segundo. A se cae pasado ~420 rps; B sigue sirviendo todo.</p>
    </div>
  </div>
  <footer><Origen>GKE · make stress · rampa de 100 a 1.500 rps · 1 corrida</Origen><Origen>Hilos: OpenBLAS arranca uno por núcleo del nodo</Origen></footer>
</div>

<!--
(5:30) Con la misma carga, A usa 15 veces más memoria. Y con un pico, los 17 procesos se pelean la misma CPU. Ahora lo vemos: es el primer evento.
Los hilos: numpy (OpenBLAS) también cuenta los 8 núcleos. En esta app no cambia nada medible.
-->

---

<div class="demo vivo">
  <div class="cabecera">
    <h1>El pico</h1>
    <p>Subimos la carga a <strong>550 rps</strong> por versión, en las dos al mismo tiempo.</p>
  </div>
  <Arena />
  <div class="lateral">
    <Grafana :panel="6" title="Requests OK por segundo" />
    <Grafana :panel="10" title="CPU throttling" />
    <Qr target="arena" :size="96" label="Sigan comprando" />
  </div>
</div>

<!--
(6:45, ~3 min) Hacer: en la terminal, `make load RATE=550 DURATION=3m` (la arena más k6 tienen que quedar bajo ~600 rps por versión).
Decir: miren los errores de A subir en el tablero y los de B no. Los paneles: A sirve ~300 rps y su CPU throttling llega al 100%; B sirve los 550.
Prometheus mide cada 10 s: lo que ven va unos 15 s atrasado. Al terminar: `make load RATE=200` y seguir. Si el cluster no responde, se ven las capturas.
-->

---

<div class="bandas">
  <h2 class="largo">Un proceso por contenedor, y escala con réplicas</h2>
  <div class="evidencia apilado">
    <div class="fila">
      <dl class="reglas">
        <div><dt>Lo simple</dt><dd>1 proceso por contenedor y escalar con réplicas: <span class="num">107 MiB</span>, 550 rps sin errores, arranque de <span class="num">0,7 s</span>.</dd></div>
        <div><dt>Si necesitas varios</dt><dd>Cuéntalos desde <code>cpu.max</code>, o fíjalos con <code>PYTHON_CPU_COUNT=1</code> desde Python 3.13: <span class="num">270 MiB</span> con 3 workers, 550 rps sin errores.</dd></div>
        <div><dt>Nunca</dt><dd><code>os.cpu_count()</code> dentro de un contenedor.</dd></div>
      </dl>
      <div class="par"><Seal word="workers" :size="104" ghost /><Seal word="memoria" :size="104" ghost /></div>
    </div>
    <table class="receta cifras">
      <thead><tr><th>Mismas 2 CPUs por versión</th><th>Procesos</th><th>Rinde hasta, sin errores</th></tr></thead>
      <tbody>
        <tr><th>2 pods × 1 CPU × 1 proceso</th><td>2</td><td><span class="num">~570–620 rps</span></td></tr>
        <tr><th>1 pod × 2 CPU × 2 workers</th><td>2</td><td><span class="num">~430 rps</span></td></tr>
        <tr><th>1 pod × 2 CPU × 1 proceso</th><td>1</td><td><span class="num">~300 rps</span> (el GIL deja una CPU sin usar)</td></tr>
        <tr><th>Versión A: 2 pods × 17 workers</th><td>34</td><td><span class="num">~420 rps</span></td></tr>
      </tbody>
    </table>
  </div>
  <footer><Origen>GKE · rampa de 100 a 1.000 rps · 1 corrida por fila · sin errores y p95 &lt; 300 ms</Origen><Origen>Fila de A: make stress</Origen><Origen>Una práctica sobre la imagen A: GKE y Podman, 1 corrida</Origen></footer>
</div>

<!--
(9:45) Lo que sale del pico: un proceso por contenedor y escalar con réplicas. Con el mismo total de 2 CPUs, dos pods rinden más que un pod grande; un solo proceso no aprovecha 2 CPUs (GIL).
Si necesitan varios workers, que los cuenten desde cpu.max.
-->

---

<div class="bandas">
  <h2>2. Que la señal llegue al proceso</h2>
  <div class="evidencia dos">

```sh
PID 1 /bin/sh -c ./start.sh  # no reenvía SIGTERM
└─ /bin/sh ./start.sh
   └─ gunicorn               # nunca se entera
      └─ 17 workers
```

  <div class="consecuencia">
    <p>Kubernetes espera el grace period y manda <strong>SIGKILL</strong>. Lo que estaba en curso muere a la mitad.</p>
    <Seal word="pérdidas" :size="150" class="stamp" v-click />
  </div>
  </div>
  <footer><Origen>ps dentro del pod de la versión A</Origen></footer>
</div>

<!--
(11:45) Segundo síntoma: los deploys. En forma shell, PID 1 es un sh que no reenvía señales. Ni siquiera el CMD en JSON lo arregla si start.sh no hace exec.
Ahora el segundo evento, con la arena todavía abierta.
-->

---

<div class="demo vivo">
  <div class="cabecera">
    <h1>Un deploy</h1>
    <p>Desplegamos las dos versiones mientras compran. Miren <strong>cobradas sin orden</strong>.</p>
  </div>
  <Arena />
  <div class="lateral">
    <Grafana :panel="7" title="Errores por segundo" />
    <Grafana :panel="13" title="Réplicas listas" />
    <Qr target="arena" :size="96" label="Sigan comprando" />
  </div>
</div>

<!--
(13:00, ~3 min) Hacer: con la carga en 200 rps, `make rollout`.
Decir: durante ~40 s no pasa nada visible; después A pierde órdenes, cuando se acaba el grace period (incluye los 15 s del preStop). B no pierde ninguna.
Mostrar el contador de cobradas sin orden de cada versión en la arena. Si el cluster no responde, se ven las capturas.
-->

---

<div class="bandas">
  <h2>Cobradas, sin orden</h2>
  <div class="evidencia dos">
    <div class="consecuencia">
      <Tabla title="Por deploy" unit="~150 órdenes/s por versión" :rows="[
        { label: 'Órdenes con error', a: '~30', b: '0', loss: true },
        { label: 'Cobradas sin orden', a: '24–30', b: '0', loss: true },
        { label: 'Apagado', a: '30 s', b: '0,4 s' },
      ]" />
      <p class="chica">Se cuenta con una consulta SQL entre los cobros y la tabla de órdenes, no restando logs.</p>
    </div>
    <div class="arreglo">

```sh
#!/bin/sh
exec gunicorn -c gunicorn_conf.py app:app
```

<p>Con <code>exec</code> y el <code>CMD</code> en forma exec: <span class="num">2</span> errores y <span class="num">0</span> cobradas por deploy, apagado en <span class="num">0,6 s</span>.</p>
<Seal word="pérdidas" :size="120" ghost />
    </div>
  </div>
  <footer><Origen>GKE · cobros contados en el servicio de pagos contra órdenes confirmadas</Origen><Origen>Apagado: Podman</Origen></footer>
</div>

<!--
(16:00) 4 de cada 5 órdenes que fallan ya estaban cobradas: el SIGKILL llega mientras la app espera a pagos. El arreglo es una palabra: exec.
Hadolint revisa la forma del CMD, no el exec dentro del script.
-->

---

<div class="bandas">
  <h2 class="largo">3. Una imagen que no pese</h2>
  <div class="evidencia apilado">
    <div class="fila">
      <div class="pesos">
        <div class="peso"><span class="barra" style="--w: 100%"></span><p><strong class="num">1,46 GB</strong> <code>python:3.13</code> y pip</p></div>
        <div class="peso"><span class="barra" style="--w: 31.4%"></span><p><strong class="num">459 MB</strong> solo con <code>-slim</code></p></div>
        <div class="peso"><span class="barra" style="--w: 26.8%"></span><p><strong class="num">392 MB</strong> slim, dos etapas y uv</p></div>
      </div>
      <Tabla title="Además del peso" unit="Imagen completa (A) contra slim en dos etapas (B)" :rows="[
        { label: 'Vulnerabilidades conocidas', a: '4.265', b: '212' },
        { label: 'Capas nuevas por cada cambio de código', a: '311 MB', b: '0,01 MB' },
        { label: 'Rebuild tras cambiar una línea', a: '14 s', b: '5 s' },
        { label: 'Pull en un nodo frío', a: '', b: '', pending: true },
      ]" />
    </div>
    <div class="fila">
      <Seal word="peso" :size="104" foot="medido en Podman" class="stamp" v-click />
      <Seal word="peso" :size="104" foot="medido en Podman" ghost v-click />
      <div class="lineas">
        <p><strong>Bytecode precompilado:</strong> arranque de B <span class="num">1,6 s</span> → <span class="num">0,9 s</span>.</p>
        <p><strong>Usuario no-root</strong> <code>USER 1000</code>: seguridad, no cambia ningún número.</p>
      </div>
    </div>
  </div>
  <footer><Origen>Podman · benchmarks/image.sh</Origen><Origen>Trivy 0.76.2, base del 10 de noviembre</Origen></footer>
</div>

<!--
(17:30) Tercer síntoma: la imagen. El cambio más barato es una palabra en el FROM; las dos etapas sacan las herramientas de build. El lockfile se copia antes que el código para que el cache de capas sirva.
16 vulnerabilidades críticas en A, ninguna en B. Cada cambio de código en A vuelve a subir y bajar 311 MB, porque el código se copia antes del pip install.
PENDIENTE: medir el pull en un nodo frío con el cluster arriba. No dar ese número hasta que exista.
-->

---

<div class="bandas">
  <h2>Donde la buena también falla</h2>
  <div class="evidencia dos">
    <Rampa :xmax="1400" />
    <div class="consecuencia">
      <p>Sobre ~650 rps, B cae más que A: su único proceso no alcanza a responder el readiness probe y Kubernetes lo saca del Service.</p>
      <p><strong>Escala antes de llegar ahí.</strong></p>
    </div>
  </div>
  <footer><Origen>GKE · make stress · mismo manifiesto para las dos · 1 corrida</Origen></footer>
</div>

<!--
(20:00) Los límites, sin adornos: 1 proceso por pod rinde más antes del límite, pero no se defiende sola de una sobrecarga. HPA antes del punto de quiebre.
-->

---

<div class="bandas">
  <h2>Para el lunes</h2>
  <div class="evidencia">
    <ol class="preparacion">
      <li>Calcula los workers desde el límite del contenedor, o corre 1 proceso por contenedor. Nunca con <code>os.cpu_count()</code>.</li>
      <li><code>exec</code> al final del script de arranque y el <code>CMD</code> en forma exec.</li>
      <li>INFO o WARNING en producción y formato perezoso, <code>log.debug("x=%s", x)</code>: <span class="num">+31%</span> de CPU con DEBUG a la misma carga.</li>
      <li>Base <code>slim</code> con versión fija y multi-stage.</li>
      <li>Bytecode precompilado: <code>UV_COMPILE_BYTECODE=1</code>.</li>
      <li>Usuario no-root con UID numérico: <code>USER 1000</code>.</li>
    </ol>
  </div>
  <footer><Origen>CHECKLIST.md, con el resto de las prácticas</Origen><Origen>CPU con DEBUG: GKE, 200 rps, contra INFO</Origen></footer>
</div>

<!--
(22:00) Lo que se llevan para el lunes. Las dos primeras arreglan fallas distintas y ninguna basta sola. El checklist completo está en el repo.
-->

---

<div class="paquete cierre">
  <div class="marca">
    <h1>Sin sellos</h1>
    <p>El checklist completo y los scripts para reproducir cada número.</p>
  </div>
  <div class="sellos"><Seal word="memoria" :size="124" ghost /><Seal word="workers" :size="124" ghost /><Seal word="pérdidas" :size="124" ghost /><Seal word="peso" :size="124" foot="medido en Podman" ghost /><Seal word="arranque" :size="124" foot="medido en Podman" ghost /></div>
  <div class="pie"><span>Gracias</span><span class="muted">PyCon Chile 2026 · Diego Parra</span></div>
  <div class="lado">
    <Tabla unit="Misma carga, mismos recursos" :rows="[
      { label: 'Memoria por pod', a: '1.375 MiB', b: '90 MiB' },
      { label: 'Cobradas sin orden, por deploy', a: '24–30', b: '0', loss: true },
      { label: 'Servidas en un pico de 550 rps', a: '~300/s', b: '550/s' },
      { label: 'Imagen', a: '1,46 GB', b: '392 MB' },
    ]" origin="GKE · 2 pods de 1 CPU y 2 GiB por versión · imagen: Podman" />
    <Qr target="repo" label="Repo y checklist" :size="124" />
  </div>
</div>

<!--
(24:30) Cierre. Preguntas desde el 25:00.
-->
