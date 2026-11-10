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
      { label: 'Imagen', a: '1,44 GB', b: '377 MB' },
    ]" origin="GKE · 2 pods de 1 CPU y 2 GiB por versión · imagen: Podman" />
    <Qr target="arena" label="Escanea y compra" :size="124" />
  </div>
</div>

<!--
(0:00) Abrir con la pregunta: ¿cuántos de ustedes tienen Python corriendo en un contenedor? Esto es lo mismo, dos veces.
Los sellos son como los de los alimentos: se ganan con umbrales medidos, y la tabla dice cuánto pesa cada versión.
Si el QR ya funciona, que lo escaneen ahora: lo vamos a usar en unos minutos.
-->

---

<div class="bandas">
  <h2>Una tienda. Un <code>app.py</code>.</h2>
  <div class="evidencia">

```python
@app.post("/orders")
async def create_order(order: Order):
    total = order_total(order)
    response = await app.state.payments.post(
        PAYMENTS_URL, json={"customer_id": order.customer_id, "amount": total}
    )
    response.raise_for_status()
    return {"total": total, "payment_id": response.json()["payment_id"]}
```

  <div class="flujo">
    <p><strong>Catálogo</strong> con pandas, leído de un bucket al arrancar.</p>
    <p><strong>Órdenes</strong> que cobran en un servicio de pagos de ~150 ms.</p>
  </div>
  </div>
  <footer><Origen>app/app.py · FastAPI</Origen></footer>
</div>

<!--
(1:00) La app es aburrida a propósito: lee un catálogo, cobra una orden. Lo que nos importa es cómo se empaca y cómo arranca.
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
(2:00) Esto es todo lo que cambia. El A es el Dockerfile que sale de cualquier tutorial. Nada de esto rompe un test ni un linter.
-->

---

<div class="bandas">
  <h2>Las reglas del ensayo</h2>
  <div class="evidencia">
    <dl class="reglas">
      <div><dt>Mismo código</dt><dd>El mismo <code>app.py</code> en las dos imágenes.</dd></div>
      <div><dt>Mismo manifiesto</dt><dd>Los dos Deployments solo difieren en el nombre y la imagen.</dd></div>
      <div><dt>Mismos recursos</dt><dd>2 pods de 1 CPU y 2 GiB, un nodo <code>e2-standard-8</code> por versión.</dd></div>
      <div><dt>Misma carga</dt><dd>k6 a tasa constante contra las dos al mismo tiempo.</dd></div>
    </dl>
  </div>
  <footer><Origen>GKE · make up</Origen></footer>
</div>

<!--
(3:00) Si una comparación no es justa, no sirve. Mismo manifiesto, mismos recursos, misma carga. Todo lo que van a ver se reproduce con los scripts del repo.
-->

---

<div class="bandas">
  <h2>Cómo se gana un sello</h2>
  <div class="evidencia umbrales">
    <div><Seal word="memoria" :size="168" class="stamp" v-click /><p>Más de 512 MiB por pod con 200 rps</p></div>
    <div><Seal word="workers" :size="168" class="stamp" v-click /><p>Más procesos que CPUs en su límite</p></div>
    <div><Seal word="pérdidas" :size="168" class="stamp" v-click /><p>Alguna orden perdida o cobrada sin confirmar en un deploy</p></div>
    <div><Seal word="peso" :size="168" foot="medido en Podman" class="stamp" v-click /><p>Una imagen de más de 1 GB</p></div>
    <div><Seal word="arranque" :size="168" foot="medido en Podman" class="stamp" v-click /><p>Más de 5 s hasta el primer 200</p></div>
  </div>
  <footer><p class="muted">Umbrales de esta charla, no de la ley. La versión B no gana ninguno.</p></footer>
</div>

<!--
(4:00) Cada clic estampa un sello en la versión A. Los umbrales son nuestros, pero cada uno se cruza con una medición.
-->

---

<div class="demo">
  <Qr target="arena" :size="380" />
  <div>
    <h1>Saquen el celular</h1>
    <p>Toquen <strong>COMPRAR</strong>. Cada toque es una orden real, la misma para A y para B.</p>
  </div>
</div>

<!--
DEMO 1 (5:00, ~3 min). Cambiar a la pantalla de la arena (/screen). k6 corre de fondo a 200 rps por versión.
Mensaje: en un día tranquilo, A y B son idénticas. Si alguien ve diferencias, que lo diga: no hay.
Volver al deck cuando los dos lienzos vayan parejos.
-->

---

<div class="bandas">
  <h2>Las dos, en vivo</h2>
  <div class="evidencia sala">
    <Grafana :panel="6" title="Requests OK por segundo" />
    <Grafana :panel="7" title="Errores por segundo" />
    <Grafana :panel="11" title="Memoria por pod" />
    <Grafana :panel="10" title="CPU throttling" />
  </div>
  <footer><Origen>Grafana en el cluster · bad = A, good = B</Origen><Origen>Prometheus mide cada 10 s: lo que ven va unos 15 s atrasado</Origen></footer>
</div>

<!--
(8:00) Mismo tráfico, mismos números de servicio. Lo único distinto ya se ve: la memoria por pod.
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
(8:00) Esta es la práctica que más pesa. Dentro del contenedor, os.cpu_count() miente: ve el nodo, no la cuota.
El límite vive en cgroups: cpu.max = 100 ms cada 100 ms, o sea 1 CPU. gunicorn calcula 2n+1 con n = 8.
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
(9:30) 15 veces más memoria para servir lo mismo. Y con un pico, los 17 procesos se pelean la misma CPU: throttling al 100%.
Los hilos: numpy (OpenBLAS) también cuenta los 8 núcleos, 8 hilos por proceso. En esta app no cambia nada medible, pero en cargas numéricas sí.
-->

---

<div class="demo vivo">
  <Qr target="arena" :size="230" label="Sigan comprando" />
  <div class="pantalla">
    <h1>El pico</h1>
    <p>Subimos la carga a <strong>550 rps</strong> por versión, para las dos al mismo tiempo.</p>
    <div class="paneles">
      <Grafana :panel="6" title="Requests OK por segundo" />
      <Grafana :panel="10" title="CPU throttling" />
    </div>
  </div>
</div>

<!--
DEMO 2 (11:00, ~3 min). En la terminal: make load RATE=<k6> (k6 + el tope de la arena tiene que quedar bajo ~600 rps por versión).
Cambiar a la arena: el lienzo de A se llena de rojo, el de B no. Mostrar Grafana: CPU throttling 100% contra ~5%.
Volver a 200 rps antes de seguir.
-->

---

<div class="bandas">
  <h2>Un proceso por contenedor</h2>
  <div class="evidencia dos">
    <dl class="reglas">
      <div><dt>Lo simple</dt><dd>1 proceso por contenedor y escalar con réplicas: <span class="num">107 MiB</span>, 550 rps sin errores, arranque de <span class="num">0,7 s</span>.</dd></div>
      <div><dt>Si necesitas varios</dt><dd>Cuéntalos desde <code>cpu.max</code>, o fíjalos con <code>PYTHON_CPU_COUNT=1</code> desde Python 3.13: <span class="num">270 MiB</span> con 3 workers, 550 rps sin errores.</dd></div>
      <div><dt>Nunca</dt><dd><code>os.cpu_count()</code> dentro de un contenedor.</dd></div>
    </dl>
    <div class="par vertical"><Seal word="workers" :size="132" ghost /><Seal word="memoria" :size="132" ghost /><Seal word="arranque" :size="132" foot="medido en Podman" ghost /></div>
  </div>
  <footer><Origen>GKE · la imagen A con esa sola práctica aplicada · 1 corrida por variante</Origen><Origen>Arranque: Podman</Origen></footer>
</div>

<!--
(14:00) Una sola práctica, aplicada a la imagen mala, saca tres sellos.
Dato para preguntas: con el mismo total de CPU, 2 pods de 1 CPU sirven ~570 rps y 1 pod de 2 CPUs con 2 workers ~430. Un solo proceso no aprovecha 2 CPUs (GIL).
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
(15:00) En forma shell, PID 1 es un sh que no reenvía señales. Ni siquiera el CMD en JSON lo arregla si start.sh no hace exec.
-->

---

<div class="demo vivo">
  <Qr target="arena" :size="230" label="Sigan comprando" />
  <div class="pantalla">
    <h1>Un deploy</h1>
    <p>Desplegamos las dos versiones mientras compran. Miren el contador de <strong>cobradas sin orden</strong>.</p>
    <div class="paneles">
      <Grafana :panel="7" title="Errores por segundo" />
      <Grafana :panel="13" title="Réplicas listas" />
    </div>
  </div>
</div>

<!--
DEMO 3 (16:00, ~3 min). make rollout con la arena en pantalla. A pierde órdenes ~40 s después, cuando se acaba el grace period (incluye los 15 s del preStop). B no pierde ninguna.
-->

---

<div class="bandas">
  <h2>Cobradas, sin orden</h2>
  <div class="evidencia dos">
    <Tabla title="Por deploy" unit="~150 órdenes/s por versión" :rows="[
      { label: 'Órdenes con error', a: '~30', b: '0', loss: true },
      { label: 'Cobradas sin confirmar', a: '24–30', b: '0', loss: true },
      { label: 'Apagado', a: '30 s', b: '0,4 s' },
    ]" />
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
(19:00) 4 de cada 5 órdenes que fallan ya estaban cobradas: el SIGKILL llega mientras la app espera a pagos.
Hadolint revisa la forma del CMD, no el exec dentro del script.
-->

---

<div class="bandas">
  <h2>3. Sin DEBUG en producción</h2>
  <div class="evidencia dos">
    <div>
      <p class="cifra">+31<small>%</small></p>
      <p class="rotulo">de CPU por pod con la misma carga, solo por pasar de INFO a DEBUG</p>
    </div>

```python
# 463 rps, aunque DEBUG esté desactivado
log.debug(f"catálogo {json.dumps(catalogo)}")

# 934 rps sin esa línea
```

  </div>
  <footer><Origen>CPU: GKE, 200 rps, DEBUG contra INFO</Origen><Origen>Throughput: Podman, 1 worker de uvicorn</Origen></footer>
</div>

<!--
(20:30) La f-string se evalúa siempre, aunque el nivel la descarte: json.dumps del catálogo en cada request. Formato perezoso: log.debug("x=%s", x).
-->

---

<div class="bandas">
  <h2>4. Una imagen que no pese</h2>
  <div class="evidencia">
    <div class="pesos">
      <div class="peso"><span class="barra" style="--w: 100%"></span><p><strong class="num">1,44 GB</strong> <code>python:3.13</code> y pip</p></div>
      <div class="peso"><span class="barra" style="--w: 30.6%"></span><p><strong class="num">440 MB</strong> solo con <code>-slim</code></p></div>
      <div class="peso"><span class="barra" style="--w: 26.2%"></span><p><strong class="num">377 MB</strong> slim, dos etapas y uv</p></div>
    </div>
    <div class="par vertical">
      <Seal word="peso" :size="150" foot="medido en Podman" class="stamp" v-click />
      <Seal word="peso" :size="150" foot="medido en Podman" ghost v-click />
    </div>
  </div>
  <footer><Origen>Podman · tamaño de la imagen</Origen><p class="muted">Se descarga en cada nodo nuevo; el tiempo de pull no lo medí.</p></footer>
</div>

<!--
(22:00) El cambio más barato: una palabra en el FROM. Las dos etapas sacan las herramientas de build.
-->

---

<div class="bandas">
  <h2>5 y 6. Lo que queda</h2>
  <div class="evidencia envases">
    <div class="ingredientes">
      <b>Bytecode precompilado</b>
      <code>UV_COMPILE_BYTECODE=1</code> (pip ya lo hace). Arranque de la versión B: <span class="num">1,6 s</span> → <span class="num">0,9 s</span>.
    </div>
    <div class="ingredientes">
      <b>Usuario no-root</b>
      <code>USER 1000</code>, numérico: Kubernetes no puede verificar <code>runAsNonRoot</code> con un nombre. Es seguridad: no cambia ningún número de esta charla.
    </div>
  </div>
  <footer><Origen>Arranque: Podman, contenedor creado → primer 200</Origen></footer>
</div>

<!--
(23:00) Higiene: rápido de aplicar, impacto chico en rendimiento.
-->

---

<div class="bandas">
  <h2>Qué saca cada práctica</h2>
  <div class="evidencia">
    <table class="receta">
      <thead><tr><th>Práctica</th><th>Sellos que saca</th><th>Medido</th></tr></thead>
      <tbody>
        <tr><th>1. Workers según la CPU</th><td>memoria, workers, arranque</td><td><span class="num">1.375 → 107 MiB</span>, pico sin errores</td></tr>
        <tr><th>2. <code>exec</code> al arrancar</th><td>pérdidas</td><td><span class="num">24–30 → 0</span> cobradas por deploy</td></tr>
        <tr><th>3. Sin DEBUG</th><td>—</td><td><span class="num">+31%</span> de CPU si lo dejas</td></tr>
        <tr><th>4. Imagen slim</th><td>peso</td><td><span class="num">1,44 GB → 440 MB</span></td></tr>
        <tr><th>5. Bytecode</th><td>—</td><td><span class="num">1,6 → 0,9 s</span> de arranque</td></tr>
        <tr><th>6. No-root</th><td>—</td><td>seguridad</td></tr>
      </tbody>
    </table>
  </div>
  <footer><Origen>Cada fila: la imagen A con una sola práctica aplicada, salvo bytecode (versión B)</Origen></footer>
</div>

<!--
(24:00) Las dos primeras arreglan fallas distintas y ninguna basta sola: una arregla memoria y picos, la otra los deploys.
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
(25:00) Ser honestos con los límites: 1 proceso por pod rinde más antes del límite, pero no se defiende sola de una sobrecarga. HPA antes del punto de quiebre.
-->

---

<div class="bandas">
  <h2>Modo de preparación</h2>
  <div class="evidencia">
    <ol class="preparacion">
      <li>Calcula los workers desde el límite del contenedor, o corre 1 proceso por contenedor. Nunca con <code>os.cpu_count()</code>.</li>
      <li><code>exec</code> al final del script de arranque y el <code>CMD</code> en forma exec.</li>
      <li>INFO o WARNING en producción, y formato perezoso: <code>log.debug("x=%s", x)</code>.</li>
      <li>Base <code>slim</code> con versión fija y multi-stage.</li>
      <li>Bytecode precompilado: <code>UV_COMPILE_BYTECODE=1</code>.</li>
      <li>Usuario no-root con UID numérico: <code>USER 1000</code>.</li>
    </ol>
  </div>
  <footer><Origen>CHECKLIST.md, con el resto de las prácticas</Origen></footer>
</div>

<!--
(25:30) Lo que se llevan para el lunes. El checklist completo está en el repo.
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
      { label: 'Imagen', a: '1,44 GB', b: '377 MB' },
    ]" origin="GKE · 2 pods de 1 CPU y 2 GiB por versión · imagen: Podman" />
    <Qr target="repo" label="Repo y checklist" :size="124" />
  </div>
</div>

<!--
(26:00) Cierre. Preguntas.
-->
