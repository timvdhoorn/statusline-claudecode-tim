// src/components/ModelSegment.tsx
import { Text } from 'ink';
import { colors } from '../utils/colors';
import { icons } from '../utils/icons';

interface Props {
  displayName: string;
}

function formatModelName(name: string): string {
  if (name.includes('Opus')) return 'Opus 4.5';
  if (name.includes('Sonnet')) return 'Sonnet 4';
  if (name.includes('Haiku')) return 'Haiku';
  return name;
}

export function ModelSegment({ displayName }: Props) {
  const name = formatModelName(displayName);

  return (
    <Text>
      <Text color={colors.model} bold>{icons.model}</Text>
      <Text color={colors.model}> {name}</Text>
    </Text>
  );
}
