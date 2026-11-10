<script setup lang="ts">
type Row = { label: string, a: string, b: string, loss?: boolean, sub?: boolean, pending?: boolean }
const props = defineProps<{ title?: string, rows: Row[], unit?: string, origin?: string }>()
</script>

<template>
  <figure class="tabla">
    <figcaption>{{ props.title ?? 'Información de despliegue' }}</figcaption>
    <div class="unit">{{ props.unit ?? 'Por pod, misma carga' }}</div>
    <table>
      <thead><tr><th /><th>A</th><th>B</th></tr></thead>
      <tbody>
        <tr v-for="row in props.rows" :key="row.label" :class="{ sub: row.sub }">
          <th scope="row">{{ row.label }}</th>
          <td :class="{ loss: row.loss, pend: row.pending }">{{ row.pending ? 'PENDIENTE' : row.a }}</td>
          <td :class="{ pend: row.pending }">{{ row.pending ? 'PENDIENTE' : row.b }}</td>
        </tr>
      </tbody>
    </table>
    <div v-if="props.origin" class="origin">{{ props.origin }}</div>
  </figure>
</template>

<style scoped>
.tabla { border: 3px solid var(--ink); padding: 14px 18px 12px; margin: 0; background: var(--paper); }
figcaption { font-family: var(--display); font-stretch: 75%; font-weight: 900; font-size: 34px; line-height: 1; }
.unit { font-size: 15px; font-weight: 600; padding: 6px 0 8px; border-bottom: 12px solid var(--ink); }
table { width: 100%; border-collapse: collapse; font-variant-numeric: tabular-nums; }
thead th { font-size: 15px; font-weight: 800; text-align: right; padding: 6px 0 4px; border-bottom: 4px solid var(--ink); }
tbody th { text-align: left; font-weight: 700; font-size: 18px; padding: 8px 12px 8px 0; }
td { text-align: right; font-family: var(--mono); font-size: 18px; font-weight: 600; padding: 8px 0 8px 18px; white-space: nowrap; }
tbody tr { border-bottom: 1px solid var(--ink); }
tbody tr:last-child { border-bottom: 4px solid var(--ink); }
tr.sub th { font-weight: 500; padding-left: 16px; }
td.loss, td.pend { color: var(--loss); }
td.pend { font-weight: 800; letter-spacing: .04em; }
.origin { font-size: 12.5px; font-weight: 600; padding-top: 8px; color: var(--ink); }
</style>
