// src/components/UsageSegment.tsx
import { Text } from 'ink';
import { colors, getPctColor } from '../utils/colors';
import { getCircleIcon } from '../utils/icons';
import { formatResetTime } from '../utils/format';
import type { UsageData } from '../types';

interface Props {
  usage: UsageData | null;
}

export function UsageSegment({ usage }: Props) {
  if (!usage) {
    return (
      <Text>
        <Text color={colors.usage}>󰪞</Text>
        <Text color={colors.usage}> ?%</Text>
      </Text>
    );
  }

  const pct = Math.round(usage.fiveHourPct);
  const color = getPctColor(pct, colors.usage);
  const icon = getCircleIcon(pct);
  const resetTime = formatResetTime(usage.resetsAt);

  return (
    <Text>
      <Text color={color}>{icon}</Text>
      <Text color={color}> {pct}% · {resetTime}</Text>
    </Text>
  );
}
