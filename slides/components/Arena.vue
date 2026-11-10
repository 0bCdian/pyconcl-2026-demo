<script setup lang="ts">
import { onMounted, ref } from 'vue'

const url = import.meta.env.VITE_ARENA_SCREEN_URL as string | undefined
const FALLBACK = '/fallback/arena.png'
const state =ref<'checking' | 'live' | 'image' | 'box'>('checking')
onMounted(async () => {
  if (!url) return
  const abort = new AbortController()
  const timer = setTimeout(() => abort.abort(), 3000)
  try {
    await fetch(url, { mode: 'no-cors', signal: abort.signal })
    state.value = 'live'
  } catch {
    state.value = 'image'
  } finally {
    clearTimeout(timer)
  }
})
</script>

<template>
  <div v-if="!url" class="arena pendiente"><b>Falta la URL</b>VITE_ARENA_SCREEN_URL</div>
  <iframe v-else-if="state === 'live'" class="arena" :src="url" title="Arena" />
  <img v-else-if="state === 'image'" class="arena" :src="FALLBACK" alt="Arena" @error="state = 'box'">
  <div v-else class="arena sin-conexion"><b>Arena</b>Sin conexión al cluster</div>
</template>

<style scoped>
.arena { display: block; width: 100%; height: 100%; min-height: 0; border: 3px solid var(--ink); background: var(--paper); object-fit: contain; box-sizing: border-box; }
.pendiente, .sin-conexion { display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 4px; text-align: center; font-size: 18px; font-weight: 600; }
.pendiente { border: 3px dashed var(--loss); color: var(--loss); font-family: var(--mono); font-weight: 700; }
.pendiente b, .sin-conexion b { font-family: var(--display); font-stretch: 75%; font-size: 30px; font-weight: 900; text-transform: uppercase; line-height: 1; }
</style>
