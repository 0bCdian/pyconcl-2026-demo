<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(defineProps<{
  word: string
  size?: number
  ghost?: boolean
  foot?: string
}>(), { size: 200, foot: 'medido en GKE' })
// Words longer than seven letters shrink so they stay inside the keyline.
const wordScale = computed(() => Math.min(1, 7 / props.word.length))
</script>

<template>
  <div class="seal" :class="{ ghost: props.ghost }" :style="{ width: `${props.size}px`, height: `${props.size}px`, fontSize: `${props.size / 10}px` }" role="img" :aria-label="`Alto en ${props.word}`">
    <svg viewBox="0 0 200 200" aria-hidden="true">
      <polygon class="body" points="58.6,0 141.4,0 200,58.6 200,141.4 141.4,200 58.6,200 0,141.4 0,58.6" />
      <polygon class="keyline" points="61.9,8 138.1,8 192,61.9 192,138.1 138.1,192 61.9,192 8,138.1 8,61.9" />
    </svg>
    <div class="label">
      <span class="alto">ALTO EN</span>
      <span class="word" :style="{ fontSize: `${1.9 * wordScale}em` }">{{ props.word }}</span>
      <span class="foot">{{ props.foot }}</span>
    </div>
  </div>
</template>

<style scoped>
.seal { position: relative; flex: none; }
svg { position: absolute; inset: 0; width: 100%; height: 100%; }
.body { fill: var(--ink); }
.keyline { fill: none; stroke: var(--paper); stroke-width: 3; }
.label {
  position: absolute; inset: 14% 10%; display: flex; flex-direction: column; align-items: center; justify-content: center;
  color: var(--paper); text-align: center; font-family: var(--display); font-stretch: 72%; line-height: .92; text-transform: uppercase;
}
.alto { font-size: 1.5em; font-weight: 800; letter-spacing: .02em; }
.word { font-weight: 900; margin-top: .1em; white-space: nowrap; }
.foot { font-size: max(.6em, 10px); font-weight: 600; letter-spacing: .08em; margin-top: .9em; opacity: .9; }
.ghost .body { fill: var(--paper); stroke: var(--ghost); stroke-width: 3; stroke-dasharray: 7 6; }
.ghost .keyline { stroke: none; }
.ghost .label { color: var(--ghost-ink); }
.ghost .word { text-decoration: line-through; text-decoration-thickness: 3px; }
</style>
