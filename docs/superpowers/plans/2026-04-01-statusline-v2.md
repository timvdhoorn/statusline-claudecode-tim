# Statusline v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplify the statusline to use only stdin JSON from Claude Code, removing all external API calls and cache files, and add version display.

**Architecture:** Single bash script reads JSON from stdin via `jq`, renders two-line statusline. No external API calls, no cache files, no shared state between sessions. Git info still fetched via git commands.

**Tech Stack:** Bash, jq, git

---

### Task 1: Remove TypeScript implementation

**Files:**
- Delete: `typescript/` (entire directory)

- [ ] **Step 1: Delete the TypeScript directory**

```bash
rm -rf typescript/
```

- [ ] **Step 2: Verify removal**

```bash
ls typescript/ 2>&1
```

Expected: `ls: typescript/: No such file or directory`

- [ ] **Step 3: Commit**

```bash
git add -A typescript/
git commit -m "chore: remove TypeScript statusline implementation"
```

---

### Task 2: Simplify model segment — use display_name directly + add version

**Files:**
- Modify: `statusline-tim.sh:62-73`

Replace the hardcoded model version mapping (lines 62-73) with direct use of `display_name` from stdin JSON, and append the Claude Code version in grey.

- [ ] **Step 1: Replace model segment**

Replace lines 62-73 in `statusline-tim.sh`:

```bash
# === MODEL ===
model_display=$(echo "$input" | jq -r '.model.display_name // "Unknown"' | tr -d '\n\r')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 1000000' | tr -d '\n\r')
is_1m=""
{ echo "$model_display" | grep -qi "1m"; } && is_1m="1"
[ "$ctx_size" -gt 200000 ] 2>/dev/null && is_1m="1"
case "$model_display" in
    *"Opus"*)   [ -n "$is_1m" ] && model_display="Opus 4.6 1M" || model_display="Opus 4.6" ;;
    *"Sonnet"*) [ -n "$is_1m" ] && model_display="Sonnet 4.6 1M" || model_display="Sonnet 4.6" ;;
    *"Haiku"*)  model_display="Haiku 4.5" ;;
esac
MODEL_SEG="${MODEL_COLOR}${model_display}"
```

With:

```bash
# === MODEL ===
model_display=$(echo "$input" | jq -r '.model.display_name // "Unknown"' | tr -d '\n\r')
cc_version=$(echo "$input" | jq -r '.version // empty' | tr -d '\n\r')
VERSION_SEG=""
[ -n "$cc_version" ] && VERSION_SEG=" ${GRAY}v${cc_version}"
MODEL_SEG="${MODEL_COLOR}${model_display}${VERSION_SEG}"
```

- [ ] **Step 2: Test with sample input**

```bash
echo '{"model":{"display_name":"Opus 4.6 1M"},"version":"2.1.89","workspace":{"current_dir":"/tmp"},"context_window":{"context_window_size":1000000},"cost":{}}' | bash statusline-tim.sh
```

Expected: Output starts with `Opus 4.6 1M` followed by `v2.1.89` (in grey).

- [ ] **Step 3: Test without version field**

```bash
echo '{"model":{"display_name":"Sonnet 4.6"},"workspace":{"current_dir":"/tmp"},"context_window":{"context_window_size":200000},"cost":{}}' | bash statusline-tim.sh
```

Expected: Output shows `Sonnet 4.6` with no version suffix.

- [ ] **Step 4: Commit**

```bash
git add statusline-tim.sh
git commit -m "feat: show display_name directly and add version in grey"
```

---

### Task 3: Replace API usage segment with stdin rate_limits

**Files:**
- Modify: `statusline-tim.sh:182-278`

Remove the entire OAuth/cache/fetch machinery (lines 182-278) and replace with simple jq reads from stdin JSON.

- [ ] **Step 1: Replace usage segment**

Replace lines 182-278 in `statusline-tim.sh` (everything from `# === API USAGE ===` through the `USAGE_SEG` assignment) with:

```bash
# === API USAGE ===
five_hour_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' | tr -d '\n\r')
resets_at_epoch=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty' | tr -d '\n\r')

USAGE_SEG=""
if [ -n "$five_hour_pct" ] && [ "$five_hour_pct" != "null" ]; then
    five_hour_int=$(awk "BEGIN {printf \"%.0f\", $five_hour_pct}" 2>/dev/null || echo "0")
    usage_icon=$(get_usage_icon "$five_hour_int")

    reset_formatted="?"
    if [ -n "$resets_at_epoch" ] && [ "$resets_at_epoch" != "null" ]; then
        resets_at_int=$(awk "BEGIN {printf \"%.0f\", $resets_at_epoch}" 2>/dev/null)
        if [ -n "$resets_at_int" ]; then
            today=$(date "+%Y-%m-%d")
            reset_day=$(date -j -f "%s" "$resets_at_int" "+%Y-%m-%d" 2>/dev/null)
            if [ "$today" = "$reset_day" ]; then
                reset_formatted=$(date -j -f "%s" "$resets_at_int" "+%H:%M" 2>/dev/null || echo "?")
            else
                reset_formatted=$(date -j -f "%s" "$resets_at_int" "+%d-%m %H:%M" 2>/dev/null || echo "?")
            fi
        fi
    fi

    USG_COLOR=$(get_pct_color "${five_hour_int:-0}" "$USAGE_COLOR")
    USAGE_SEG="${GRAY}${usage_icon} ${USG_COLOR}${five_hour_int}% ${GRAY}· ${reset_formatted}"
fi
```

- [ ] **Step 2: Test with rate_limits present**

```bash
echo '{"model":{"display_name":"Opus 4.6"},"version":"2.1.89","workspace":{"current_dir":"/tmp"},"context_window":{"context_window_size":200000,"used_percentage":42},"rate_limits":{"five_hour":{"used_percentage":23,"resets_at":1743550800}},"cost":{"total_duration_ms":720000}}' | bash statusline-tim.sh
```

Expected: Shows `5h 23%` with a reset time.

- [ ] **Step 3: Test without rate_limits (non-Pro or first message)**

```bash
echo '{"model":{"display_name":"Opus 4.6"},"workspace":{"current_dir":"/tmp"},"context_window":{"context_window_size":200000},"cost":{}}' | bash statusline-tim.sh
```

Expected: No usage segment shown (no `5h` text in output).

- [ ] **Step 4: Commit**

```bash
git add statusline-tim.sh
git commit -m "feat: read 5h usage from stdin rate_limits, remove OAuth API call"
```

---

### Task 4: Simplify context segment — remove cache

**Files:**
- Modify: `statusline-tim.sh:157-180`

Remove the context cache file logic and use `used_percentage` from stdin directly.

- [ ] **Step 1: Replace context segment**

Replace lines 157-180 in `statusline-tim.sh` (from `CTX_CACHE_FILE` through the `fi` closing the cache fallback) with:

```bash
# === CONTEXT ===
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty | floor' | tr -d '\n\r')

CONTEXT_SEG=""
if [ -n "$used_pct" ] && [ "$used_pct" != "null" ]; then
    ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 1000000' | tr -d '\n\r')
    used_tokens=$((ctx_size * used_pct / 100))
    used_k=$((used_tokens / 1000))
    CTX_COLOR=$(get_pct_color "$used_pct" "$CONTEXT_COLOR")
    CONTEXT_SEG="${GRAY}${ICON_CONTEXT} ${CTX_COLOR}${used_pct}% ${GRAY}· ${used_k}k"
fi
```

Note: `ctx_size` is now read here instead of in the model segment (which no longer needs it).

- [ ] **Step 2: Remove ctx_size from old model segment location**

After Task 2, the model segment no longer reads `ctx_size`. Verify it's not referenced elsewhere except in the new context segment.

- [ ] **Step 3: Test with context data**

```bash
echo '{"model":{"display_name":"Opus 4.6"},"workspace":{"current_dir":"/tmp"},"context_window":{"context_window_size":1000000,"used_percentage":42.5},"cost":{}}' | bash statusline-tim.sh
```

Expected: Shows `ctx 42% · 420k`.

- [ ] **Step 4: Test without context data**

```bash
echo '{"model":{"display_name":"Opus 4.6"},"workspace":{"current_dir":"/tmp"},"context_window":{"context_window_size":200000},"cost":{}}' | bash statusline-tim.sh
```

Expected: No context segment shown.

- [ ] **Step 5: Commit**

```bash
git add statusline-tim.sh
git commit -m "feat: read context from stdin directly, remove cache file"
```

---

### Task 5: Update output assembly for optional segments

**Files:**
- Modify: `statusline-tim.sh:280-287`

Since CONTEXT_SEG and USAGE_SEG can now be empty, update the LINE1 assembly to handle optional separators.

- [ ] **Step 1: Replace output assembly**

Replace lines 280-287 with:

```bash
# === OUTPUT (2 lines) ===
LINE1="${MODEL_SEG}"
[ -n "$CONTEXT_SEG" ] && LINE1="${LINE1}${SEP}${CONTEXT_SEG}"
[ -n "$USAGE_SEG" ] && LINE1="${LINE1}${SEP}${USAGE_SEG}"

# Duration
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0' | tr -d '\n\r')
if [ "${duration_ms:-0}" -gt 0 ] 2>/dev/null; then
    total_sec=$((duration_ms / 1000))
    if [ "$total_sec" -lt 60 ]; then
        duration_fmt="${total_sec}s"
    elif [ "$total_sec" -lt 3600 ]; then
        duration_fmt="$((total_sec / 60))m"
    else
        duration_fmt="$((total_sec / 3600))h$((total_sec % 3600 / 60))m"
    fi
    LINE1="${LINE1}${SEP}${GRAY}${ICON_TIME} ${duration_fmt}"
fi

LINE2="${DIR_SEG}"
[ -n "$GIT_SEG" ] && LINE2="${LINE2}${SEP}${GIT_SEG}"
[ -n "$WORKTREE_SEG" ] && LINE2="${LINE2}${SEP}${WORKTREE_SEG}"
[ -n "$COMMIT_SEG" ] && LINE2="${LINE2}${SEP}${COMMIT_SEG}"

printf '%s\n%s%s\n' "$LINE1" "$LINE2" "$RESET"
```

- [ ] **Step 2: Test full output with all fields**

```bash
echo '{"model":{"display_name":"Opus 4.6 1M"},"version":"2.1.89","workspace":{"current_dir":"/tmp"},"context_window":{"context_window_size":1000000,"used_percentage":42},"rate_limits":{"five_hour":{"used_percentage":23,"resets_at":1743550800}},"cost":{"total_duration_ms":720000,"total_lines_added":10,"total_lines_removed":3}}' | bash statusline-tim.sh
```

Expected: Two lines with model+version, context, usage, duration on line 1.

- [ ] **Step 3: Test minimal output (no optional fields)**

```bash
echo '{"model":{"display_name":"Haiku 4.5"},"workspace":{"current_dir":"/tmp"},"context_window":{"context_window_size":200000},"cost":{}}' | bash statusline-tim.sh
```

Expected: Line 1 shows only model name, no separators for missing segments.

- [ ] **Step 4: Commit**

```bash
git add statusline-tim.sh
git commit -m "feat: handle optional segments in output assembly"
```

---

### Task 6: Update example.json and copy to ~/.claude

**Files:**
- Modify: `example.json` (root level — move from typescript/)
- Copy: `statusline-tim.sh` → `~/.claude/statusline-tim.sh`

- [ ] **Step 1: Create updated example.json at root**

```bash
cat > example.json << 'JSONEOF'
{
  "model": {
    "display_name": "Opus 4.6 1M"
  },
  "version": "2.1.89",
  "session_id": "abc123",
  "workspace": {
    "current_dir": "/Users/timvdhoorn/Documents/10-Projects/Github/Claude/statusline-claudecode-tim"
  },
  "context_window": {
    "context_window_size": 1000000,
    "used_percentage": 6.5,
    "current_usage": {
      "input_tokens": 45000,
      "output_tokens": 12000,
      "cache_creation_input_tokens": 5000,
      "cache_read_input_tokens": 3000
    }
  },
  "rate_limits": {
    "five_hour": {
      "used_percentage": 23,
      "resets_at": 1743550800
    }
  },
  "cost": {
    "total_lines_added": 127,
    "total_lines_removed": 23,
    "total_duration_ms": 345000
  }
}
JSONEOF
```

- [ ] **Step 2: Test with example.json**

```bash
cat example.json | bash statusline-tim.sh
```

Expected: Full two-line output with all segments.

- [ ] **Step 3: Copy script to ~/.claude**

```bash
cp statusline-tim.sh ~/.claude/statusline-tim.sh
```

- [ ] **Step 4: Verify Claude Code config still points to correct location**

```bash
jq '.statusLine' ~/.claude/settings.json
```

Expected: `{ "type": "command", "command": "~/.claude/statusline-tim.sh", "padding": 0 }`

- [ ] **Step 5: Commit**

```bash
git add example.json statusline-tim.sh
git commit -m "chore: update example.json with new fields, sync to ~/.claude"
```

---

### Task 7: Clean up stale cache files

- [ ] **Step 1: Remove old cache and lock files**

```bash
rm -f ~/.claude/statusline_usage_cache.json
rm -f ~/.claude/statusline_ctx_cache.json
rm -f ~/.claude/statusline_usage.lock
```

- [ ] **Step 2: Verify no references remain**

```bash
grep -r "statusline_usage_cache\|statusline_ctx_cache\|statusline_usage.lock" statusline-tim.sh
```

Expected: No matches.
