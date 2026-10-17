// src/components/ModelSegment.tsx
import { Text } from 'ink';
import { colors } from '../utils/colors';
import { icons } from '../utils/icons';

interface Props {
  displayName: string;
  contextWindowSize?: number;
}

function formatModelName(name: string, contextWindowSize?: number): string {
  const is1M = name.includes('1m') || name.includes('1M') || (contextWindowSize != null && contextWindowSize > 200000);
  if (name.includes('Opus')) return is1M ? 'Opus 4.6 1M' : 'Opus 4.6';
  if (name.includes('Sonnet')) return is1M ? 'Sonnet 4.6 1M' : 'Sonnet 4.6';
  if (name.includes('Haiku')) return 'Haiku 4.5';
  return name;
}

export function ModelSegment({ displayName, contextWindowSize }: Props) {
  const name = formatModelName(displayName, contextWindowSize);

  return (
    <Text>
      <Text color={colors.model} bold>{icons.model}</Text>
      <Text color={colors.model}> {name}</Text>
    </Text>
  );
}
