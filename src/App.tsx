// src/App.tsx
import { useState, useEffect } from 'react';
import { Box, Text } from 'ink';
import type { StatuslineInput, GitInfo } from './types';
import { getGitInfo } from './utils/git';
import { useApiUsage } from './hooks/useApiUsage';
import { ModelSegment } from './components/ModelSegment';
import { DirSegment } from './components/DirSegment';
import { GitSegment } from './components/GitSegment';
import { CommitSegment } from './components/CommitSegment';
import { ContextSegment } from './components/ContextSegment';
import { UsageSegment } from './components/UsageSegment';
import { TimeSegment } from './components/TimeSegment';
import { Separator } from './components/Separator';

interface Props {
  input: StatuslineInput;
}

export function App({ input }: Props) {
  const [gitInfo, setGitInfo] = useState<GitInfo | null>(null);
  const usage = useApiUsage();
  const currentDir = input.workspace.current_dir;

  useEffect(() => {
    getGitInfo(currentDir).then(setGitInfo);
  }, [currentDir]);

  return (
    <Box flexDirection="column">
      {/* Line 1: Model | Context | Usage | Time */}
      <Box>
        <ModelSegment displayName={input.model.display_name} />
        <Separator />
        <ContextSegment contextWindow={input.context_window} />
        <Separator />
        <UsageSegment usage={usage} />
        <Separator />
        <TimeSegment durationMs={input.cost.total_duration_ms} />
      </Box>

      {/* Line 2: Dir | Git | Commit */}
      <Box>
        <DirSegment currentDir={currentDir} />
        {gitInfo && (
          <>
            <Separator />
            <GitSegment
              gitInfo={gitInfo}
              linesAdded={input.cost.total_lines_added}
              linesRemoved={input.cost.total_lines_removed}
            />
            {gitInfo.lastCommitTimestamp && (
              <>
                <Separator />
                <CommitSegment timestamp={gitInfo.lastCommitTimestamp} />
              </>
            )}
          </>
        )}
      </Box>
    </Box>
  );
}
