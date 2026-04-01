# Statusline v2 — Stdin-Only Architecture

## Summary

Simplify the statusline by removing the TypeScript implementation and all external API calls, switching entirely to the JSON data Claude Code provides via stdin. Adds version display and eliminates session isolation issues.

## Changes

### Remove

- `/typescript/` directory (entire TypeScript/React implementation)
- OAuth token retrieval (macOS Keychain + `~/.claude/.credentials.json`)
- Cache file: `~/.claude/statusline_usage_cache.json`
- Cache file: `~/.claude/statusline_ctx_cache.json`
- Lock file: `~/.claude/statusline_usage.lock`
- Hardcoded model version mapping (Opus 4.6, Sonnet 4.6, Haiku 4.5)

### Modify: `statusline-tim.sh`

**Model segment:**
- Use `model.display_name` from stdin JSON directly (no hardcoded versions)
- Append `version` field from stdin JSON in grey (subtext color)
- Example: `Opus 4.6 1M v2.1.89` (version in grey)

**5h usage segment:**
- Read `rate_limits.five_hour.used_percentage` from stdin JSON
- Read `rate_limits.five_hour.resets_at` from stdin JSON
- Remove: OAuth API call, cache read/write, lock file logic
- Keep: color thresholds (green < 60%, yellow 60-80%, red > 80%)
- Handle: field may be absent (non-Pro users or before first API response)

**Context segment:**
- Read `context_window.used_percentage` from stdin JSON directly
- Remove: separate context cache file logic

**Git segment:**
- No changes (already reads from git commands)

### Data Flow

```
Claude Code stdin JSON → jq parse → render segments → terminal output
```

No external API calls. No shared cache files. No session isolation issues.

### Stdin JSON Fields Used

| Field | Segment | Fallback |
|-------|---------|----------|
| `model.display_name` | Model | show raw name |
| `version` | Model (grey) | hide if absent |
| `context_window.used_percentage` | Context | hide if absent |
| `context_window.context_window_size` | Context (1M detection) | — |
| `rate_limits.five_hour.used_percentage` | 5h Usage | hide segment |
| `rate_limits.five_hour.resets_at` | 5h Usage (reset time) | — |
| `cost.total_duration_ms` | Duration | hide if 0 |
| `workspace.current_dir` | Directory | — |

### Example Output

```
 Opus 4.6 1M v2.1.89  ctx 42%  5h 23%  12m
 ~/projects/foo  main +2 ~3
```

### Session Isolation

Fixed by design: each statusline invocation receives its own stdin JSON from Claude Code. No shared state between sessions.
