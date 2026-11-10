<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(defineProps<{ panel: number, title: string, from?: string }>(), { from: 'now-10m' })
const BASE = import.meta.env.VITE_GRAFANA_URL ?? 'http://localhost:8001/api/v1/namespaces/monitoring/services/kps-grafana:80/proxy'
const src = computed(() => `${BASE}/d-solo/shop/shop?orgId=1&panelId=${props.panel}&theme=light&hideLogo=true&refresh=5s&from=${props.from}&to=now`)
</script>

<template>
  <iframe class="grafana" :src="src" :title="props.title" />
</template>

<style scoped>
.grafana { display: block; width: 100%; height: 100%; min-height: 0; border: 3px solid var(--ink); background: var(--paper); }
</style>
