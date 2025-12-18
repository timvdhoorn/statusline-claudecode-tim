// src/components/DirSegment.tsx
import { Text } from 'ink';
import { homedir } from 'os';
import { colors } from '../utils/colors';
import { icons } from '../utils/icons';
import { shortenPath } from '../utils/format';

interface Props {
  currentDir: string;
}

export function DirSegment({ currentDir }: Props) {
  const displayPath = shortenPath(currentDir, homedir());

  return (
    <Text>
      <Text color={colors.dirIcon}>{icons.folder}</Text>
      <Text color={colors.gray}> {displayPath}</Text>
    </Text>
  );
}
