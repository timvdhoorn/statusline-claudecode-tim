// src/utils/icons.ts
export const icons = {
  model: '✳',
  folder: '󰉋',
  git: '󰊢',
  context: '󱘲',
  time: '󱦻',
  commit: '󰜘',
  synced: '󰓦',
  diverged: '󰓧',
  clean: '✓',
  dirty: '●',
  conflict: '⚠',
} as const;

export function getCircleIcon(pct: number): string {
  if (pct <= 12) return '󰪞';
  if (pct <= 25) return '󰪟';
  if (pct <= 37) return '󰪠';
  if (pct <= 50) return '󰪡';
  if (pct <= 62) return '󰪢';
  if (pct <= 75) return '󰪣';
  if (pct <= 87) return '󰪤';
  return '󰪥';
}
