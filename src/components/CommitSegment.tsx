// src/components/CommitSegment.tsx
import { Text } from 'ink';
import { colors } from '../utils/colors';
import { icons } from '../utils/icons';
import { formatTimeAgo } from '../utils/format';

interface Props {
  timestamp: number;
}

export function CommitSegment({ timestamp }: Props) {
  const timeAgo = formatTimeAgo(timestamp);

  return (
    <Text>
      <Text color={colors.gray}>{icons.commit}</Text>
      <Text color={colors.gray}> {timeAgo}</Text>
    </Text>
  );
}
