// src/components/TimeSegment.tsx
import { Text } from 'ink';
import { colors } from '../utils/colors';
import { icons } from '../utils/icons';
import { formatDuration } from '../utils/format';

interface Props {
  durationMs: number;
}

export function TimeSegment({ durationMs }: Props) {
  const display = formatDuration(durationMs);

  return (
    <Text>
      <Text color={colors.time}>{icons.time}</Text>
      <Text color={colors.time}> {display}</Text>
    </Text>
  );
}
