// src/index.tsx
import { render } from 'ink';
import { App } from './App';
import type { StatuslineInput, GitInfo, UsageData } from './types';
import { getGitInfo } from './utils/git';
import { getOAuthToken } from './utils/oauth';
import { homedir } from 'os';
import { join } from 'path';

const CACHE_FILE = join(homedir(), '.claude', 'statusline_usage_cache.json');
const CACHE_DURATION = 60;

interface CacheData {
  five_hour: number;
  resets_at: string;
  cached_at: number;
}

async function getApiUsage(): Promise<UsageData | null> {
  // Try cache first
  try {
    const file = Bun.file(CACHE_FILE);
    if (await file.exists()) {
      const data: CacheData = await file.json();
      const age = Math.floor(Date.now() / 1000) - data.cached_at;
      if (age < CACHE_DURATION) {
        return { fiveHourPct: data.five_hour, resetsAt: data.resets_at };
      }
    }
  } catch {}

  // Fetch fresh
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

      // Write cache
      const cacheData: CacheData = {
        five_hour: fiveHour,
        resets_at: resetsAt,
        cached_at: Math.floor(Date.now() / 1000),
      };
      await Bun.write(CACHE_FILE, JSON.stringify(cacheData));

      return { fiveHourPct: fiveHour, resetsAt };
    }
  } catch {}

  return null;
}

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

  // Fetch all async data BEFORE rendering (parallel)
  const [gitInfo, usage] = await Promise.all([
    getGitInfo(input.workspace.current_dir),
    getApiUsage(),
  ]);

  // Reset ANSI and render once
  process.stdout.write('\x1b[0m');

  const { waitUntilExit } = render(
    <App input={input} gitInfo={gitInfo} usage={usage} />,
    { exitOnCtrlC: false }
  );
  await waitUntilExit();
}

main().catch(console.error);
