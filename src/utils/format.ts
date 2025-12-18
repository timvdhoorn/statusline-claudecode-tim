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
