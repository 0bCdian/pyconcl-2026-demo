<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'

const props = withDefaults(defineProps<{ panel: number, title: string, from?: string }>(), { from: 'now-10m' })
const BASE = import.meta.env.VITE_GRAFANA_URL ?? 'http://localhost:8001/api/v1/namespaces/monitoring/services/kps-grafana:80/proxy'
const src = computed(() => `${BASE}/d-solo/shop/shop?orgId=1&panelId=${props.panel}&theme=light&hideLogo=true&refresh=5s&from=${props.from}&to=now`)

const state = ref<'checking' | 'live' | 'image' | 'box'>('checking')
onMounted(async () => {
  const abort = new AbortController()
  const timer = setTimeout(() => abort.abort(), 3000)
  try {
    await fetch(`${BASE}/api/health`, { mode: 'no-cors', signal: abort.signal })
    state.value = 'live'
  } catch {
    state.value = 'image'
  } finally {
    clearTimeout(timer)
  }
})
</script>

<template>
  <iframe v-if="state === 'live'" class="grafana" :src="src" :title="props.title" />
  <img v-else-if="state === 'image'" class="grafana" :src="`/fallback/panel-${props.panel}.png`" :alt="props.title" @error="state = 'box'">
  <div v-else class="grafana sin-conexion"><b>{{ props.title }}</b>Sin conexión al cluster</div>
</template>

<style scoped>
.grafana { display: block; width: 100%; height: 100%; min-height: 0; border: 3px solid var(--ink); background: var(--paper); object-fit: contain; box-sizing: border-box; }
.sin-conexion { display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 4px; text-align: center; font-size: 18px; font-weight: 600; }
.sin-conexion b { font-family: var(--display); font-stretch: 75%; font-size: 22px; font-weight: 900; text-transform: uppercase; line-height: 1; }
</style>
