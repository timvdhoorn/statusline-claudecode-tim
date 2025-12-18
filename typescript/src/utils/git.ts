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
