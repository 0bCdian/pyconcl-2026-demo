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
    <Seal word="memoria" :size="190" foot="medido en Podman" />
    <Seal word="señales" :size="190" foot="medido en Podman" />
    <Seal word="peso" :size="190" foot="medido en Podman" />
  </div>
  <div class="pie"><span>PyCon Chile 2026</span><span class="muted">Online</span><span class="muted">Diego Parra</span></div>
  <div class="lado">
    <Tabla unit="Mismo código, 1 CPU por contenedor" :rows="[
      { label: 'Memoria por pod', a: '1.430 MiB', b: '95 MiB' },
      { label: 'Rebuild, 1 línea', a: '20–21 s', b: '3,5 s' },
      { label: 'Cobradas sin orden', a: '26–30', b: '0', loss: true },
      { label: 'Imagen', a: '1,46 GB', b: '392 MB' },
    ]" origin="GKE 11 nov · Podman 15 nov" />
  </div>
</div>

<!--
(0:00, 0:45) Es la misma app dos veces, en un contenedor, con una diferencia: cómo está construido y cómo arranca. Vamos a subir una escalera, una práctica por escalón, y en cada una veremos qué mejora y en qué entorno.
La tabla es el resumen de la charla. Las demos son en mi laptop con Podman; las pruebas de carga ya están medidas en GKE y se muestran como resultados finales. Llévenlo a su plataforma: Kubernetes, Cloud Run, ECS o una VM.
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
    <p><strong>Catálogo</strong> de productos.</p>
    <p><strong>Órdenes</strong>: cobran en un servicio de pagos (~150 ms) y después se guardan en PostgreSQL.</p>
    <p class="loss"><strong>Si el proceso muere entre los dos pasos, hay un cobro sin orden.</strong></p>
  </div>
  </div>
  <footer><Origen>app/app.py · FastAPI</Origen></footer>
</div>

<!--
(0:45, 1:30) La app es aburrida a propósito. Cobra y guarda. Si el proceso muere justo entre el cobro y el insert, el cliente pagó y no tiene nada. Esa es la métrica de la charla: cobradas sin orden, contadas con una consulta SQL entre los cobros y la tabla de órdenes, no restando logs.
-->

---

<div class="bandas">
  <h2>Dos imágenes, el mismo código</h2>
  <div class="evidencia">
    <table class="receta cifras">
      <thead><tr><th></th><th>Versión A</th><th>Versión B</th></tr></thead>
      <tbody>
        <tr><th>Base</th><td><code>python:3.13</code></td><td><code>python:3.13-slim</code>, dos etapas</td></tr>
        <tr><th>Dependencias</th><td><code>pip install</code> después del código</td><td><code>uv sync --frozen</code> antes del código</td></tr>
        <tr><th>Arranque</th><td><code>CMD ./start.sh</code> sin <code>exec</code></td><td><code>CMD ["uvicorn", …]</code></td></tr>
        <tr><th>Procesos</th><td><code>cpu_count() * 2 + 1</code> workers</td><td>1 proceso</td></tr>
        <tr><th>Usuario</th><td>root</td><td><code>USER 1000</code></td></tr>
      </tbody>
    </table>
  </div>
  <footer><Origen>deploy/bad/Dockerfile</Origen><Origen>deploy/good/Dockerfile</Origen></footer>
</div>

<!--
(2:15, 1:30) Todo lo que cambia. A es el Dockerfile que sale de cualquier tutorial: nada rompe un test ni un linter. B aplica una práctica por fila. Tres problemas de producción: builds lentos, autoescalado lento y deploys que pierden órdenes. Cada uno viene de una práctica que falta.
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

---

<div class="bandas">
  <h2>Builds lentos, y cuánto cuestan</h2>
  <div class="evidencia dos">
    <Tabla title="Tras cambiar 1 línea" unit="A contra B" :rows="[
      { label: 'Rebuild', a: '20–21 s', b: '3,5 s' },
      { label: 'Capas nuevas por deploy', a: '311 MB', b: '0,01 MB' },
      { label: 'Imagen', a: '1,46 GB', b: '392 MB' },
      { label: 'Comprimida en el registro', a: '545 MB', b: '114 MB' },
    ]" />
    <div class="lineas">
      <p><strong>CI:</strong> minutos de build en cada commit.</p>
      <p><strong>Artifact Registry:</strong> almacenamiento y egress por cada versión.</p>
      <p><strong>Nodos:</strong> el disco efímero se llena de imágenes.</p>
      <p class="loss"><strong>CI sin caché</strong> (Cloud Build): 79 s contra 82 s. Si el CI no guarda las capas, el orden no ayuda.</p>
    </div>
  </div>
  <footer><Origen>Rebuild: Podman · 15 nov · 5 corridas</Origen><Origen>Capas nuevas: Podman · 11 nov · image.sh</Origen><Origen>Comprimida: GKE · pull</Origen><Origen>Cloud Build · 15 nov · 1 corrida</Origen><Origen>docs.docker.com/build/cache/optimize</Origen></footer>
</div>

<!--
(6:00, 2:00) La causa: A copia el código antes de pip install, así que cualquier cambio invalida la capa de dependencias; B copia primero el lockfile, instala y deja el código en la última capa (los pasos que cambian seguido van al final, dice la documentación de Docker). Resultado: 311 MB de capas nuevas por cambio contra 0,01 MB.
Implicaciones: minutos de CI, almacenamiento y egress en el registro (545 MB contra 114 MB comprimida, por imagen y por versión) y disco efímero del nodo.
Ojo, medido en Cloud Build sin caché: build completo A 79 s, B 82 s, iguales. El orden de capas solo ahorra si el CI conserva la caché (cache-from, caché del runner). Sin eso, todos los builds son el peor caso.
-->

---

<div class="bandas">
  <h2>Autoescalado lento</h2>
  <div class="evidencia dos">
    <Tabla title="Réplica nueva" unit="A contra B" :rows="[
      { label: 'Arranque en Podman', a: '9–13 s', b: '2,2 s' },
      { label: 'Arranque en GKE, imagen ya en el nodo', a: '20–26 s', b: '5 s' },
      { label: 'Réplica nueva en nodo frío (pull + arranque)', a: '39–45 s', b: '13 s', loss: true },
    ]" />
    <div class="consecuencia">
      <p>Cuando sube el tráfico, las réplicas nuevas de A <strong>llegan tarde</strong>.</p>
      <p class="chica">En un nodo nuevo se suma: el pull y el arranque.</p>
    </div>
  </div>
  <footer><Origen>Podman y GKE · 15 nov · 3 corridas</Origen><Origen>Nodo frío: GKE · 15 nov · 2 pods por versión</Origen></footer>
</div>

<!--
(10:00, 2:00) Arranque: 9–13 s contra 2,2 s (5 corridas), porque A arranca 17 procesos que importan pandas cada uno en 1 CPU. En GKE, con la imagen ya en el nodo: 20–26 s contra 5 s. En un nodo frío, que es lo que pasa cuando el autoscaler agrega nodos, se suma el pull (21 s contra 7 s): 39–45 s contra 13 s hasta que la réplica recibe tráfico. El autoscaler agrega réplicas cuando ya hay tráfico; cada segundo de arranque es tráfico que cae sobre las réplicas que ya existen.
-->

---

<div class="bandas">
  <h2>¿Dónde corre tu app?</h2>
  <div class="evidencia apilado">
    <div class="fila">
      <p class="chica">La guía de Docker de gunicorn recomienda <code>workers = cpu_count() * 2 + 1</code>. Es la config de A.</p>
    </div>
    <table class="receta cifras">
      <thead><tr><th>Entorno</th><th><code>os.cpu_count()</code></th><th>Workers</th><th>CPU real</th></tr></thead>
      <tbody>
        <tr><th>VM e2-standard-8, sin contenedor</th><td><span class="num">8</span></td><td><span class="num">17</span></td><td>8</td></tr>
        <tr><th>Pod GKE, límite de 1 CPU, mismo tipo de máquina</th><td><span class="num">8</span></td><td><span class="num">17</span></td><td class="loss"><span class="num">1</span></td></tr>
        <tr><th>Cloud Run, 1 vCPU</th><td><span class="num">5–6</span></td><td class="loss"><span class="num">11–13</span></td><td class="loss"><span class="num">1</span></td></tr>
      </tbody>
    </table>
  </div>
  <footer><Origen>gunicorn.org/guides/docker</Origen><Origen>docs.python.org · os.cpu_count()</Origen><Origen>GCP · 15 nov · Cloud Run: 3 ejecuciones</Origen></footer>
</div>

<!--
(12:00, 2:30) Esta config la copiamos de la guía oficial de Docker de gunicorn. En una VM es correcta: usa los 8 núcleos. En el pod, con límite de 1 CPU en la misma máquina, os.cpu_count() sigue diciendo 8 (el límite vive en cgroups, cpu.max) y salen 17 workers en 1 CPU. Python 3.13 documenta PYTHON_CPU_COUNT para "usuarios que necesitan limitar la CPU de un contenedor".
Mismo código, mismo cálculo, tres resultados según la plataforma. En la VM es correcto: con la misma config, A sirvió 550 rps con 0% de errores y p95 de 212 ms, usando 1,45 GB de 32 GB y una carga de 1,8 sobre 8 núcleos. En Cloud Run con 1 vCPU, Python vio 6, 6 y 5 CPUs en tres ejecuciones y no hay cgroup que leer: 11 a 13 workers para 1 vCPU, y en tres ejecuciones dio 6, 6 y 5.
-->

---

<div class="bandas">
  <h2>Qué cuesta contar mal</h2>
  <div class="evidencia dos">
    <Tabla title="Por pod" unit="200 rps · pico de 550 rps" :rows="[
      { label: 'Memoria', a: '1.430 MiB', b: '95 MiB' },
      { label: 'Conexiones a la base', a: '170', b: '10' },
      { label: 'Servidas en el pico', a: '~300/s', b: '550/s' },
      { label: 'p95 en el pico', a: '> 5 s', b: '≈ 255 ms', loss: true },
      { label: 'Se rompe a', a: '~450 rps', b: '~710 rps' },
    ]" />
    <div class="consecuencia">
      <p>Tres copias de A agotaron <code>max_connections=500</code> de PostgreSQL: <em>sorry, too many clients already</em>, y A murió.</p>
      <dl class="reglas">
        <div><dt>Lo simple</dt><dd>1 proceso por contenedor y escalar con réplicas.</dd></div>
        <div><dt>Varios</dt><dd><code>PYTHON_CPU_COUNT=1</code> en Python 3.13.</dd></div>
      </dl>
    </div>
  </div>
  <footer><Origen>GKE · 11 nov · 3 corridas, memoria y pico</Origen><Origen>Punto de quiebre: 1 corrida · Conexiones y max_connections: local</Origen></footer>
</div>

<!--
(14:30, 3:30) La consecuencia en Kubernetes: 1.430 MiB contra 95 MiB por pod a 200 rps, con límites de memoria eso es OOM y pods reiniciados. Cada worker abre su pool: 170 conexiones por pod contra 10; localmente tres copias de A agotaron max_connections=500 de PostgreSQL y A murió.
En el pico de 550 rps, A sirvió ~300 ok/s con p95 > 5 s y 100% de throttling de CPU; B sirvió los 550 con p95 ≈ 255 ms. A se rompe a ~450 rps; B a ~710 (una corrida).
Arreglos: 1 proceso por contenedor y escalar con réplicas, o fijar PYTHON_CPU_COUNT=1 desde Python 3.13. Lo mismo aplica a Cloud Run y a cualquier plataforma con límite de CPU.
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
(~3 min) Antes de la charla: `make load RATE=200 DURATION=60m` y la arena en autoplay. Hacer: en otra terminal, `make load RATE=550 DURATION=3m` (reemplaza la carga base; al terminar volver a `make load RATE=200 DURATION=60m`).
Decir: miren los errores de A en el tablero y los de B no. En los paneles: A sirve ~300 rps con su CPU frenada al 100%; B sirve los 550. Prometheus va ~15 s atrasado.
Si el cluster no responde, los paneles muestran la captura del ensayo.
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
(~3 min) Hacer: con la carga base de 200 rps, `make rollout`.
Decir: B termina en ~10 s; A tarda ~45 s y, cuando la plataforma la mata con SIGKILL, pierde órdenes ya cobradas. Mostrar el contador de cobradas sin orden de cada versión en el tablero.
Si el cluster no responde, los paneles muestran la captura del ensayo.
-->

---

<div class="bandas">
  <h2>Deploys lentos que pierden órdenes</h2>
  <div class="evidencia dos">
    <Tabla title="Detener una réplica" unit="A contra B · rolling deploy a 200 órdenes/s" :rows="[
      { label: 'Apagado', a: '10,2–10,3 s', b: '0,4–0,5 s' },
      { label: 'Exit code', a: '137', b: '0' },
      { label: 'Errores en el deploy', a: '30–31', b: '0–1' },
      { label: 'Cobradas sin orden', a: '26–30', b: '0', loss: true },
    ]" />
    <div class="arreglo">

```sh
#!/bin/sh
exec gunicorn -c gunicorn_conf.py app:app
```

<p>Sin <code>exec</code>, PID 1 es <code>sh</code> y no recibe SIGTERM. Con <code>exec</code>, gunicorn lo recibe y sale.</p>
<p class="loss"><strong>Rollout de 2 réplicas:</strong> A 43–47 s, B 8–12 s.</p>
    </div>
  </div>
  <footer><Origen>Apagado: Podman · 15 nov · 3 corridas</Origen><Origen>Deploy: GKE · 11 y 15 nov · 3 corridas</Origen><Origen>docs.docker.com · CMD en forma shell</Origen></footer>
</div>

<!--
(20:00, 3:30) La documentación de Docker lo dice: la forma shell no será PID 1 y no recibe señales; la solución es empezar con exec. Apagado de A: 10,2–10,3 s y exit 137; B: 0,4–0,5 s y exit 0.
En GKE, con un rolling deploy a 200 órdenes/s: A tuvo 30–31 errores de cliente y 26–30 órdenes cobradas sin guardar (se cuentan con una consulta SQL entre cobros y órdenes); B, 0–1 errores y 0 cobradas. Cada deploy de A cobra a clientes que no reciben nada.
Rollout de 2 réplicas en GKE: A 43–47 s hasta terminar y 84–88 s hasta que se van los pods viejos; B 8–12 s y 25–29 s (los 15 s del preStop incluidos). Cada deploy de A es más lento y además pierde órdenes.
-->

---

<div class="bandas">
  <h2>La escalera: qué arregló cada práctica</h2>
  <div class="evidencia">
    <table class="receta cifras">
      <thead><tr><th>Práctica</th><th>Qué arregla</th><th>Evidencia</th></tr></thead>
      <tbody>
        <tr><th>Workers según el contenedor</th><td>Memoria, pico, arranque</td><td><span class="num">1.430 → 112 MiB</span>, arranque <span class="num">0,7 s</span></td></tr>
        <tr><th>+ 1 worker, sin <code>exec</code></th><td>Deploy: nada todavía</td><td class="loss"><span class="num">26</span> cobradas sin orden (1 corrida)</td></tr>
        <tr><th>+ <code>exec</code></th><td>Pérdidas y apagado</td><td><span class="num">0</span> cobradas, apagado <span class="num">0,6 s</span></td></tr>
        <tr><th>Slim + lockfile + orden de capas</th><td>Build, pull, tamaño</td><td><span class="num">20 → 3,5 s</span> de rebuild, <span class="num">21 → 7 s</span> de pull, <span class="num">1,46 GB → 392 MB</span></td></tr>
      </tbody>
    </table>
  </div>
  <footer><Origen>Memoria y cobradas: GKE · 11 nov · 1 corrida por fila</Origen><Origen>Arranque y apagado: Podman · 11 nov</Origen><Origen>Build: Podman · 15 nov</Origen><Origen>Pull: GKE · 15 nov</Origen></footer>
</div>

<!--
(23:30, 1:30) Cada práctica arregla una cosa distinta y ninguna basta sola. Los workers arreglan memoria, pico y arranque pero con 1 worker y sin exec seguimos con 26 cobradas sin orden. El exec arregla los deploys. Slim, lockfile antes del código y buen orden de capas arreglan build, pull y tamaño.
-->

---

<div class="bandas resumen">
  <h2>Resumen y para el lunes</h2>
  <div class="evidencia">
    <Tabla title="A contra B" unit="1 CPU por contenedor" :rows="[
      { label: 'Memoria por pod', a: '1.430 MiB', b: '95 MiB' },
      { label: 'Conexiones a la base', a: '170', b: '10' },
      { label: 'Servidas en el pico de 550 rps', a: '~300/s', b: '550/s', loss: true },
      { label: 'Réplica nueva, nodo frío', a: '39–45 s', b: '13 s' },
      { label: 'Rollout de 2 réplicas', a: '43–47 s', b: '8–12 s' },
      { label: 'Cobradas sin orden', a: '26–30', b: '0', loss: true },
      { label: 'Imagen', a: '1,46 GB', b: '392 MB' },
      { label: 'Rebuild, 1 línea', a: '20–21 s', b: '3,5 s' },
      { label: 'Capas nuevas por deploy', a: '311 MB', b: '0,01 MB' },
    ]" />
    <ol class="preparacion">
      <li>Cuenta los workers desde el límite del contenedor, o 1 proceso por réplica.</li>
      <li><code>exec</code> al final del script de arranque y CMD en forma exec.</li>
      <li>Lockfile y dependencias antes del código.</li>
      <li>Base <code>slim</code> con versión fija y multi-stage.</li>
      <li>Conoce las reglas de tu plataforma: límites, apagado, CPU.</li>
    </ol>
  </div>
  <footer><Origen>GKE · 11 y 15 nov · memoria, pico, deploy, arranque</Origen><Origen>Podman · 15 nov · build</Origen></footer>
</div>

<!--
(25:00, 3:00) Cierre. Tres problemas de producción, tres causas: dónde corre tu app (workers y memoria), cómo la apaga la plataforma (señales) y cuánto pesa lo que despliegas (capas). Las respuestas cambian en una VM, en Kubernetes o en Cloud Run; las preguntas son las mismas. Para el lunes, cinco cosas; el checklist completo y los scripts están en el repo. Preguntas desde el minuto 28.
-->
