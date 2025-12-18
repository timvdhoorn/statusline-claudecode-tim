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
