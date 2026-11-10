<script setup lang="ts">
import { computed } from 'vue'

// Equal-manifest `make stress` ramp on GKE, one point per minute from Prometheus: [requested rps, served ok/s].
const RUNS = {
  A: [[140, 140], [280, 280], [420, 419], [549, 261], [701, 229], [841, 213], [980, 249], [1121, 282], [1261, 321], [1400, 324]],
  B: [[140, 140], [280, 280], [421, 420], [561, 560], [677, 202], [842, 171], [980, 174], [1121, 167], [1261, 176], [1400, 171]],
} as const

const props = withDefaults(defineProps<{ xmax?: number }>(), { xmax: 1400 })
const W = 760
const H = 420
const pad = { l: 86, r: 44, t: 44, b: 76 }
const ymax = 700
const x = (v: number) => pad.l + (v / props.xmax) * (W - pad.l - pad.r)
const y = (v: number) => H - pad.b - (v / ymax) * (H - pad.t - pad.b)
const visible = (side: 'A' | 'B') => RUNS[side].filter(([req]) => req <= props.xmax + 1)
const path = (side: 'A' | 'B') => visible(side).map(([req, ok], i) => `${i ? 'L' : 'M'}${x(req)},${y(ok)}`).join(' ')
const xticks = computed(() => Array.from({ length: Math.floor(props.xmax / 200) + 1 }, (_, i) => i * 200))
const yticks = [0, 200, 400, 600]
const end = (side: 'A' | 'B') => visible(side).at(-1)!
const reach = computed(() => Math.min(props.xmax, ymax))
const labelAt = computed(() => reach.value * 0.78)
const slope = computed(() => -Math.atan(((H - pad.t - pad.b) / ymax) / ((W - pad.l - pad.r) / props.xmax)) * 180 / Math.PI)
const octagon = (cx: number, cy: number, r = 10) =>
  [[-.41, -1], [.41, -1], [1, -.41], [1, .41], [.41, 1], [-.41, 1], [-1, .41], [-1, -.41]].map(([dx, dy]) => `${cx + dx * r},${cy + dy * r}`).join(' ')
</script>

<template>
  <svg class="rampa" :viewBox="`0 0 ${W} ${H}`" role="img" aria-label="Órdenes servidas por segundo según las pedidas, versión A y versión B">
    <g class="grid">
      <line v-for="t in yticks" :key="`y${t}`" :x1="pad.l" :x2="W - pad.r" :y1="y(t)" :y2="y(t)" />
    </g>
    <line class="ideal" :x1="x(0)" :y1="y(0)" :x2="x(reach)" :y2="y(reach)" />
    <text class="ideal-label" :transform="`translate(${x(labelAt)},${y(labelAt)}) rotate(${slope})`" y="-14" text-anchor="middle">lo que se pidió</text>
    <g class="axis">
      <text v-for="t in yticks" :key="`yl${t}`" :x="pad.l - 12" :y="y(t) + 9" text-anchor="end">{{ t }}</text>
      <text v-for="t in xticks" :key="`xl${t}`" :x="x(t)" :y="H - pad.b + 32" text-anchor="middle">{{ t }}</text>
      <text class="title" :x="W - pad.r" :y="H - 4" text-anchor="end">rps pedidos por versión</text>
    </g>
    <path class="line b" :d="path('B')" />
    <path class="line a" :d="path('A')" />
    <circle v-for="([req, ok]) in visible('B')" :key="`b${req}`" class="dot b" :cx="x(req)" :cy="y(ok)" r="8" />
    <polygon v-for="([req, ok]) in visible('A')" :key="`a${req}`" class="dot a" :points="octagon(x(req), y(ok))" />
    <text class="end" :x="x(end('A')[0]) + 12" :y="y(end('A')[1]) + 6">A</text>
    <text class="end" :x="x(end('B')[0]) + 12" :y="y(end('B')[1]) + 6">B</text>
  </svg>
</template>

<style scoped>
.rampa { width: 100%; height: auto; overflow: visible; font-family: var(--text); }
.grid line { stroke: var(--ghost); stroke-width: 1; }
.ideal { stroke: var(--ink); stroke-width: 3.5; stroke-dasharray: 1 9; stroke-linecap: round; }
.ideal-label { font-size: 26px; fill: var(--ink); font-weight: 600; }
.axis text { font-size: 26px; fill: var(--ink); font-variant-numeric: tabular-nums; font-weight: 600; }
.axis .title { font-size: 24px; }
.line { fill: none; stroke: var(--ink); stroke-width: 4; stroke-linejoin: round; }
.line.a { stroke-dasharray: 10 6; }
.dot.b { fill: var(--paper); stroke: var(--ink); stroke-width: 3; }
.dot.a { fill: var(--ink); }
.end { font-family: var(--display); font-stretch: 75%; font-weight: 900; font-size: 40px; fill: var(--ink); }
</style>
