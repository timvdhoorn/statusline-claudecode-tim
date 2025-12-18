// src/components/GitSegment.tsx
import { Text } from 'ink';
import { colors } from '../utils/colors';
import { icons } from '../utils/icons';
import type { GitInfo } from '../types';

interface Props {
  gitInfo: GitInfo;
  linesAdded: number;
  linesRemoved: number;
}

export function GitSegment({ gitInfo, linesAdded, linesRemoved }: Props) {
  const statusIcon = gitInfo.status === 'clean' ? icons.clean
    : gitInfo.status === 'conflict' ? icons.conflict
    : icons.dirty;

  const syncIcon = gitInfo.ahead === 0 && gitInfo.behind === 0
    ? icons.synced
    : icons.diverged;

  const extras: string[] = [];
  if (gitInfo.ahead > 0) extras.push(`↑${gitInfo.ahead}`);
  if (gitInfo.behind > 0) extras.push(`↓${gitInfo.behind}`);

  return (
    <Text>
      <Text color={colors.git}>{icons.git}</Text>
      <Text color={colors.git}> {gitInfo.branch} {statusIcon} {syncIcon}</Text>
      {extras.length > 0 && <Text color={colors.git}> {extras.join(' ')}</Text>}
      {linesAdded > 0 && <Text color={colors.green}> +{linesAdded}</Text>}
      {linesRemoved > 0 && <Text color={colors.red}> -{linesRemoved}</Text>}
    </Text>
  );
}
