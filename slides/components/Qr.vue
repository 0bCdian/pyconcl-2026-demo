<script setup lang="ts">
import { computed } from 'vue'
import { encode } from 'uqr'

const props = withDefaults(defineProps<{ target: 'arena' | 'repo', size?: number, label?: string }>(), { size: 220 })
const URLS: Record<string, string | undefined> = {
  arena: import.meta.env.VITE_ARENA_URL,
  repo: import.meta.env.VITE_REPO_URL,
}
const ENV_NAMES = { arena: 'VITE_ARENA_URL', repo: 'VITE_REPO_URL' }
const url = computed(() => URLS[props.target])
const qr = computed(() => url.value ? encode(url.value, { ecc: 'M', border: 2 }) : null)
const display = computed(() => url.value?.replace(/^https?:\/\//, ''))
</script>

<template>
  <figure class="qr">
    <div v-if="!qr" class="pendiente" :style="{ width: `${props.size}px`, height: `${props.size}px` }"><b>Falta la URL</b>{{ ENV_NAMES[props.target] }}</div>
    <svg v-else :width="props.size" :height="props.size" :viewBox="`0 0 ${qr.size} ${qr.size}`" shape-rendering="crispEdges" role="img" :aria-label="url">
      <rect :width="qr.size" :height="qr.size" fill="var(--paper)" />
      <template v-for="(row, y) in qr.data" :key="y">
        <template v-for="(on, x) in row" :key="x">
          <rect v-if="on" :x="x" :y="y" width="1" height="1" fill="var(--ink)" />
        </template>
      </template>
    </svg>
    <figcaption>
      <strong v-if="props.label">{{ props.label }}</strong>
      <span v-if="display">{{ display }}</span>
    </figcaption>
  </figure>
</template>

<style scoped>
.qr { margin: 0; display: flex; flex-direction: column; gap: 8px; }
svg { display: block; outline: 3px solid var(--ink); }
.pendiente {
  display: grid; place-items: center; padding: 10px; text-align: center; border: 3px dashed var(--loss);
  color: var(--loss); font-family: var(--mono); font-size: 10px; font-weight: 700; line-height: 1.3; overflow-wrap: anywhere;
}
.pendiente b { display: block; font-family: var(--display); font-stretch: 75%; font-size: 20px; font-weight: 900; text-transform: uppercase; }
figcaption { display: flex; flex-direction: column; gap: 2px; }
strong { font-family: var(--display); font-stretch: 75%; font-weight: 900; font-size: 24px; line-height: 1; text-transform: uppercase; }
span { font-family: var(--mono); font-size: 13px; color: var(--ink); }
</style>
