// src/utils/colors.ts
export const colors = {
  model: '#D97857',
  dirIcon: '#E5C07B',
  context: '#61AFEF',
  git: '#D19A66',
  usage: '#C678DD',
  session: '#98C379',
  time: '#56B6C2',
  gray: '#808080',
  green: '#98C379',
  yellow: '#E5C07B',
  red: '#E06C75',
} as const;

export function getPctColor(pct: number, original: string): string {
  if (pct < 60) return original;
  if (pct < 80) return colors.yellow;
  return colors.red;
}
