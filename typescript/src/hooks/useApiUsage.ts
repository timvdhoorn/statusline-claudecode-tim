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
