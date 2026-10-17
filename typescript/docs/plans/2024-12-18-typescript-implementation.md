# Statusline TypeScript Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Convert the bash statusline to TypeScript with React/Ink, maintaining all existing features.

**Architecture:** React/Ink components render two lines of status info. Utils handle git commands, OAuth, and caching. Data flows from stdin JSON through App component to segment components.

**Tech Stack:** Bun, TypeScript, React 18, Ink 5

---

### Task 1: Project Setup

**Files:**
- Create: `package.json`
- Create: `tsconfig.json`
- Create: `src/types.ts`

**Step 1: Initialize package.json**

```json
{
  "name": "statusline-tim",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "start": "bun run src/index.tsx",
    "example": "cat example.json | bun run src/index.tsx"
  },
  "dependencies": {
    "ink": "^5.0.1",
    "react": "^18.3.1"
  },
  "devDependencies": {
    "@types/bun": "latest",
    "@types/react": "^18.3.1",
    "typescript": "^5.0.0"
  }
}
```

**Step 2: Create tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "outDir": "dist",
    "rootDir": "src",
    "types": ["bun-types"]
  },
  "include": ["src/**/*"]
}
```

**Step 3: Create types.ts**

```typescript
// src/types.ts
export interface StatuslineInput {
  model: {
    display_name: string;
  };
  workspace: {
    current_dir: string;
  };
  context_window: {
    context_window_size: number;
    current_usage?: {
      input_tokens: number;
      output_tokens: number;
      cache_creation_input_tokens: number;
      cache_read_input_tokens: number;
    };
    total_input_tokens?: number;
  };
  cost: {
    total_lines_added: number;
    total_lines_removed: number;
    total_duration_ms: number;
  };
}

export interface GitInfo {
  branch: string;
  status: 'clean' | 'dirty' | 'conflict';
  ahead: number;
  behind: number;
  lastCommitTimestamp: number | null;
}

export interface UsageData {
  fiveHourPct: number;
  resetsAt: string;
}
```

**Step 4: Install dependencies**

Run: `bun install`
Expected: Dependencies installed, bun.lockb created

**Step 5: Commit**

```bash
git add package.json tsconfig.json src/types.ts bun.lockb
git commit -m "feat: initialize TypeScript project with types"
```

---

### Task 2: Utils - Colors and Icons

**Files:**
- Create: `src/utils/colors.ts`
- Create: `src/utils/icons.ts`

**Step 1: Create colors.ts**

```typescript
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
```

**Step 2: Create icons.ts**

```typescript
// src/utils/icons.ts
export const icons = {
  model: '✳',
  folder: '󰉋',
  git: '󰊢',
  context: '󱘲',
  time: '󱦻',
  commit: '󰜘',
  synced: '󰓦',
  diverged: '󰓧',
  clean: '✓',
  dirty: '●',
  conflict: '⚠',
} as const;

export function getCircleIcon(pct: number): string {
  if (pct <= 12) return '󰪞';
  if (pct <= 25) return '󰪟';
  if (pct <= 37) return '󰪠';
  if (pct <= 50) return '󰪡';
  if (pct <= 62) return '󰪢';
  if (pct <= 75) return '󰪣';
  if (pct <= 87) return '󰪤';
  return '󰪥';
}
```

**Step 3: Commit**

```bash
git add src/utils/colors.ts src/utils/icons.ts
git commit -m "feat: add color palette and icon constants"
```

---

### Task 3: Utils - Format Helpers

**Files:**
- Create: `src/utils/format.ts`

**Step 1: Create format.ts**

```typescript
// src/utils/format.ts

export function formatTokens(tokens: number): string {
  if (tokens >= 1000) {
    return `${(tokens / 1000).toFixed(1)}k`;
  }
  return String(tokens);
}

export function formatDuration(ms: number): string {
  const totalSeconds = Math.floor(ms / 1000);

  if (totalSeconds >= 3600) {
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    return `${hours}h${minutes}m`;
  }

  if (totalSeconds >= 60) {
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes}m${seconds}s`;
  }

  return `${totalSeconds}s`;
}

export function formatTimeAgo(timestamp: number): string {
  const now = Math.floor(Date.now() / 1000);
  const diff = now - timestamp;

  if (diff < 60) return `${diff}s`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h`;
  return `${Math.floor(diff / 86400)}d`;
}

export function shortenPath(path: string, home: string): string {
  let displayPath = path;

  // Replace home dir with ~
  if (displayPath.startsWith(home)) {
    displayPath = '~' + displayPath.slice(home.length);
  }

  // Shorten to ~/…/parent/folder if more than 4 levels deep
  const parts = displayPath.split('/').filter(Boolean);
  if (parts.length > 4) {
    const parent = parts[parts.length - 2];
    const folder = parts[parts.length - 1];
    return `~/…/${parent}/${folder}`;
  }

  return displayPath;
}

export function formatResetTime(isoDate: string): string {
  if (!isoDate || isoDate === 'null') return '?';

  try {
    const date = new Date(isoDate);
    const day = String(date.getDate()).padStart(2, '0');
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    return `${day}-${month} ${hours}:${minutes}`;
  } catch {
    return '?';
  }
}
```

**Step 2: Commit**

```bash
git add src/utils/format.ts
git commit -m "feat: add formatting utilities"
```

---

### Task 4: Utils - Git Commands

**Files:**
- Create: `src/utils/git.ts`

**Step 1: Create git.ts**

```typescript
// src/utils/git.ts
import type { GitInfo } from '../types';

async function run(args: string[]): Promise<{ success: boolean; stdout: string }> {
  try {
    const proc = Bun.spawn(args, {
      stdout: 'pipe',
      stderr: 'pipe',
    });
    const stdout = await new Response(proc.stdout).text();
    const exitCode = await proc.exited;
    return { success: exitCode === 0, stdout: stdout.trim() };
  } catch {
    return { success: false, stdout: '' };
  }
}

export async function getGitInfo(dir: string): Promise<GitInfo | null> {
  // Check if it's a git repo
  const isGit = await run(['git', '-C', dir, 'rev-parse', '--git-dir']);
  if (!isGit.success) return null;

  // Run commands in parallel for speed
  const [branchResult, statusResult, aheadResult, behindResult, lastCommitResult] = await Promise.all([
    run(['git', '-C', dir, 'branch', '--show-current']),
    run(['git', '-C', dir, 'status', '--porcelain']),
    run(['git', '-C', dir, 'rev-list', '--count', '@{u}..HEAD']),
    run(['git', '-C', dir, 'rev-list', '--count', 'HEAD..@{u}']),
    run(['git', '-C', dir, 'log', '-1', '--format=%ct']),
  ]);

  const branch = branchResult.stdout || 'detached';

  // Determine status
  let status: GitInfo['status'] = 'clean';
  if (statusResult.stdout) {
    if (/^(UU|AA|DD)/m.test(statusResult.stdout)) {
      status = 'conflict';
    } else {
      status = 'dirty';
    }
  }

  const ahead = parseInt(aheadResult.stdout) || 0;
  const behind = parseInt(behindResult.stdout) || 0;
  const lastCommitTimestamp = lastCommitResult.stdout ? parseInt(lastCommitResult.stdout) : null;

  return { branch, status, ahead, behind, lastCommitTimestamp };
}
```

**Step 2: Commit**

```bash
git add src/utils/git.ts
git commit -m "feat: add git utilities"
```

---

### Task 5: Utils - OAuth Token

**Files:**
- Create: `src/utils/oauth.ts`

**Step 1: Create oauth.ts**

```typescript
// src/utils/oauth.ts
import { homedir } from 'os';
import { join } from 'path';

async function run(args: string[]): Promise<{ success: boolean; stdout: string }> {
  try {
    const proc = Bun.spawn(args, {
      stdout: 'pipe',
      stderr: 'pipe',
    });
    const stdout = await new Response(proc.stdout).text();
    const exitCode = await proc.exited;
    return { success: exitCode === 0, stdout: stdout.trim() };
  } catch {
    return { success: false, stdout: '' };
  }
}

export async function getOAuthToken(): Promise<string | null> {
  // Try macOS Keychain first
  const keychain = await run([
    'security', 'find-generic-password',
    '-s', 'Claude Code-credentials', '-w'
  ]);

  if (keychain.success && keychain.stdout) {
    try {
      const data = JSON.parse(keychain.stdout);
      if (data.claudeAiOauth?.accessToken) {
        return data.claudeAiOauth.accessToken;
      }
    } catch {
      // Invalid JSON, try file fallback
    }
  }

  // Fallback to credentials file
  const credsPath = join(homedir(), '.claude', '.credentials.json');
  try {
    const file = Bun.file(credsPath);
    if (await file.exists()) {
      const data = await file.json();
      return data.claudeAiOauth?.accessToken || null;
    }
  } catch {
    // File doesn't exist or invalid JSON
  }

  return null;
}
```

**Step 2: Commit**

```bash
git add src/utils/oauth.ts
git commit -m "feat: add OAuth token retrieval"
```

---

### Task 6: Hook - useApiUsage

**Files:**
- Create: `src/hooks/useApiUsage.ts`

**Step 1: Create useApiUsage.ts**

```typescript
// src/hooks/useApiUsage.ts
import { useState, useEffect } from 'react';
import { homedir } from 'os';
import { join } from 'path';
import { getOAuthToken } from '../utils/oauth';
import type { UsageData } from '../types';

const CACHE_FILE = join(homedir(), '.claude', 'statusline_usage_cache.json');
const CACHE_DURATION = 60; // seconds

interface CacheData {
  five_hour: number;
  resets_at: string;
  cached_at: number;
}

async function readCache(): Promise<UsageData | null> {
  try {
    const file = Bun.file(CACHE_FILE);
    if (!(await file.exists())) return null;

    const data: CacheData = await file.json();
    const age = Math.floor(Date.now() / 1000) - data.cached_at;

    if (age < CACHE_DURATION) {
      return { fiveHourPct: data.five_hour, resetsAt: data.resets_at };
    }
  } catch {
    // Invalid cache
  }
  return null;
}

async function writeCache(fiveHour: number, resetsAt: string): Promise<void> {
  const data: CacheData = {
    five_hour: fiveHour,
    resets_at: resetsAt,
    cached_at: Math.floor(Date.now() / 1000),
  };
  await Bun.write(CACHE_FILE, JSON.stringify(data));
}

async function fetchUsage(): Promise<UsageData | null> {
  const token = await getOAuthToken();
  if (!token) return null;

  try {
    const response = await fetch('https://api.anthropic.com/api/oauth/usage', {
      headers: {
        'Authorization': `Bearer ${token}`,
        'anthropic-beta': 'oauth-2025-04-20',
      },
      signal: AbortSignal.timeout(2000),
    });

    if (!response.ok) return null;

    const data = await response.json();
    if (data.five_hour) {
      const fiveHour = data.five_hour.utilization || 0;
      const resetsAt = data.five_hour.resets_at || '';
      await writeCache(fiveHour, resetsAt);
      return { fiveHourPct: fiveHour, resetsAt };
    }
  } catch {
    // Network error or timeout
  }
  return null;
}

export function useApiUsage(): UsageData | null {
  const [usage, setUsage] = useState<UsageData | null>(null);

  useEffect(() => {
    let mounted = true;

    async function load() {
      // Try cache first
      const cached = await readCache();
      if (cached && mounted) {
        setUsage(cached);
        return;
      }

      // Fetch fresh data
      const fresh = await fetchUsage();
      if (fresh && mounted) {
        setUsage(fresh);
      }
    }

    load();
    return () => { mounted = false; };
  }, []);

  return usage;
}
```

**Step 2: Commit**

```bash
git add src/hooks/useApiUsage.ts
git commit -m "feat: add useApiUsage hook with caching"
```

---

### Task 7: Components - Separator

**Files:**
- Create: `src/components/Separator.tsx`

**Step 1: Create Separator.tsx**

```tsx
// src/components/Separator.tsx
import { Text } from 'ink';
import { colors } from '../utils/colors';

export function Separator() {
  return <Text color={colors.gray}> | </Text>;
}
```

**Step 2: Commit**

```bash
git add src/components/Separator.tsx
git commit -m "feat: add Separator component"
```

---

### Task 8: Components - ModelSegment

**Files:**
- Create: `src/components/ModelSegment.tsx`

**Step 1: Create ModelSegment.tsx**

```tsx
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
```

**Step 2: Commit**

```bash
git add src/components/ModelSegment.tsx
git commit -m "feat: add ModelSegment component"
```

---

### Task 9: Components - DirSegment

**Files:**
- Create: `src/components/DirSegment.tsx`

**Step 1: Create DirSegment.tsx**

```tsx
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
```

**Step 2: Commit**

```bash
git add src/components/DirSegment.tsx
git commit -m "feat: add DirSegment component"
```

---

### Task 10: Components - GitSegment

**Files:**
- Create: `src/components/GitSegment.tsx`

**Step 1: Create GitSegment.tsx**

```tsx
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
```

**Step 2: Commit**

```bash
git add src/components/GitSegment.tsx
git commit -m "feat: add GitSegment component"
```

---

### Task 11: Components - CommitSegment

**Files:**
- Create: `src/components/CommitSegment.tsx`

**Step 1: Create CommitSegment.tsx**

```tsx
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
```

**Step 2: Commit**

```bash
git add src/components/CommitSegment.tsx
git commit -m "feat: add CommitSegment component"
```

---

### Task 12: Components - ContextSegment

**Files:**
- Create: `src/components/ContextSegment.tsx`

**Step 1: Create ContextSegment.tsx**

```tsx
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
  const usage = contextWindow.current_usage;

  let totalTokens = 0;
  if (usage) {
    totalTokens = (usage.input_tokens || 0)
      + (usage.output_tokens || 0)
      + (usage.cache_creation_input_tokens || 0)
      + (usage.cache_read_input_tokens || 0);
  }

  if (totalTokens === 0) {
    totalTokens = contextWindow.total_input_tokens || 0;
  }

  const pct = size > 0 && totalTokens > 0
    ? Math.round((totalTokens / size) * 100)
    : 0;

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
```

**Step 2: Commit**

```bash
git add src/components/ContextSegment.tsx
git commit -m "feat: add ContextSegment component"
```

---

### Task 13: Components - UsageSegment

**Files:**
- Create: `src/components/UsageSegment.tsx`

**Step 1: Create UsageSegment.tsx**

```tsx
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
```

**Step 2: Commit**

```bash
git add src/components/UsageSegment.tsx
git commit -m "feat: add UsageSegment component"
```

---

### Task 14: Components - TimeSegment

**Files:**
- Create: `src/components/TimeSegment.tsx`

**Step 1: Create TimeSegment.tsx**

```tsx
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
```

**Step 2: Commit**

```bash
git add src/components/TimeSegment.tsx
git commit -m "feat: add TimeSegment component"
```

---

### Task 15: App Component

**Files:**
- Create: `src/App.tsx`

**Step 1: Create App.tsx**

```tsx
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
```

**Step 2: Commit**

```bash
git add src/App.tsx
git commit -m "feat: add main App component"
```

---

### Task 16: Entry Point

**Files:**
- Create: `src/index.tsx`

**Step 1: Create index.tsx**

```tsx
// src/index.tsx
import { render } from 'ink';
import { App } from './App';
import type { StatuslineInput } from './types';

async function main() {
  // Read JSON from stdin
  const chunks: Buffer[] = [];
  for await (const chunk of Bun.stdin.stream()) {
    chunks.push(chunk as Buffer);
  }
  const inputText = Buffer.concat(chunks).toString('utf-8');

  // Parse JSON
  let input: StatuslineInput;
  try {
    input = JSON.parse(inputText);
  } catch (error) {
    console.error('Invalid JSON input');
    process.exit(1);
  }

  // Render the statusline
  const { waitUntilExit } = render(<App input={input} />);
  await waitUntilExit();
}

main().catch(console.error);
```

**Step 2: Commit**

```bash
git add src/index.tsx
git commit -m "feat: add entry point"
```

---

### Task 17: Example JSON & Test

**Files:**
- Create: `example.json`

**Step 1: Create example.json**

```json
{
  "model": {
    "display_name": "Claude Opus 4"
  },
  "workspace": {
    "current_dir": "/Users/timvdhoorn/Documents/10-Projects/Github/Claude/statusline-claudecode-tim"
  },
  "context_window": {
    "context_window_size": 200000,
    "current_usage": {
      "input_tokens": 45000,
      "output_tokens": 12000,
      "cache_creation_input_tokens": 5000,
      "cache_read_input_tokens": 3000
    }
  },
  "cost": {
    "total_lines_added": 127,
    "total_lines_removed": 23,
    "total_duration_ms": 345000
  }
}
```

**Step 2: Test the statusline**

Run: `cat example.json | bun run src/index.tsx`
Expected: Two lines of formatted statusline output with colors and icons

**Step 3: Commit**

```bash
git add example.json
git commit -m "feat: add example JSON for testing"
```

---

### Task 18: Final Verification

**Step 1: Run full test**

Run: `cat example.json | bun run src/index.tsx`
Expected: Complete statusline with all segments rendered

**Step 2: Test with actual Claude Code** (optional)

Update `~/.claude/settings.json`:
```json
{
  "statusline": {
    "command": "bun run /Users/timvdhoorn/Documents/10-Projects/Github/Claude/statusline-claudecode-tim/src/index.tsx"
  }
}
```

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat: complete TypeScript statusline implementation"
```
