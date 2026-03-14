// src/components/ContextSegment.tsx
import { Text } from 'ink';
import { colors, getPctColor } from '../utils/colors';
import { icons } from '../utils/icons';
import { formatTokens } from '../utils/format';
import type { StatuslineInput } from '../types';

interface Props {
  contextWindow: StatuslineInput['context_window'];
}

export function ContextSegment({ contextWindow }: Props) {
  const size = contextWindow.context_window_size || 200000;

  // Prefer used_percentage from Claude Code v2.1.6+ (matches /context command)
  let pct: number;
  let totalTokens: number;

  if (contextWindow.used_percentage != null) {
    pct = Math.floor(contextWindow.used_percentage);
    totalTokens = Math.round(size * pct / 100);
  } else {
    // Fallback: calculate from raw token counts
    const usage = contextWindow.current_usage;
    totalTokens = 0;
    if (usage) {
      totalTokens = (usage.input_tokens || 0)
        + (usage.output_tokens || 0)
        + (usage.cache_creation_input_tokens || 0)
        + (usage.cache_read_input_tokens || 0);
    }
    if (totalTokens === 0) {
      totalTokens = contextWindow.total_input_tokens || 0;
    }
    pct = size > 0 && totalTokens > 0
      ? Math.round((totalTokens / size) * 100)
      : 0;
  }

  const color = getPctColor(pct, colors.context);
  const tokensDisplay = formatTokens(totalTokens);

  return (
    <Text>
      <Text color={color}>{icons.context}</Text>
      <Text color={color}> {pct}%</Text>
      {totalTokens > 0 && <Text color={color}> · {tokensDisplay}</Text>}
    </Text>
  );
}
