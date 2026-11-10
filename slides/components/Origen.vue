<template>
  <p class="origen"><slot /></p>
</template>

<style scoped>
.origen {
  display: inline-block; flex: none; max-width: none; margin: 0; padding: 3px 8px; border: 1.5px solid var(--ink);
  font-size: 13px; font-weight: 600; letter-spacing: .01em; color: var(--ink); white-space: nowrap;
}
</style>
