#!/bin/bash
# Tim's Custom Statusline for Claude Code
# 256-color, 2 lines, NO Nerd Font icons (VS Code compatible)

exec 2>/dev/null

input=$(cat)

# Colors (true-color Catppuccin Mocha theme)
# Each color includes reset (0;) to atomically switch — prevents color bleed from Claude Code UI
RESET=$'\033[0m'
MODEL_COLOR=$'\033[0;1;38;2;250;179;135m'   # #fab387 Peach
DIR_COLOR=$'\033[0;1;38;2;166;227;161m'     # #a6e3a1 Green
CONTEXT_COLOR=$'\033[0;1;38;2;137;180;250m' # #89b4fa Blue
GIT_COLOR=$'\033[0;1;38;2;203;166;247m'     # #cba6f7 Mauve
USAGE_COLOR=$'\033[0;1;38;2;203;166;247m'   # #cba6f7 Mauve
GRAY=$'\033[0;38;2;127;132;156m'            # #7f849c Overlay1
GREEN=$'\033[0;1;38;2;166;227;161m'         # #a6e3a1 Green
YELLOW=$'\033[0;1;38;2;249;226;175m'        # #f9e2af Yellow
RED=$'\033[0;1;38;2;243;139;168m'           # #f38ba8 Red

# Icons
ICON_CONTEXT="ctx"
ICON_USAGE="5h"
ICON_COMMIT="cmt"
ICON_SYNC="ok"
ICON_DIVERGE="!!"

get_pct_color() {
    local pct=$1
    local original=$2
    if [ "$pct" -lt 70 ]; then echo "$original"
    elif [ "$pct" -lt 90 ]; then echo "$YELLOW"
    else echo "$RED"
    fi
}

get_usage_icon() {
    echo "$ICON_USAGE"
}

SEP="${GRAY} | "

# === DIRECTORY (resolved early so MODEL can read project settings) ===
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // "/"' | tr -d '\n\r')

# === MODEL ===
model_display=$(echo "$input" | jq -r '.model.display_name // "Unknown"' | sed 's/ *(.*1M.*)/ 1M/' | tr -d '\n\r')
cc_version=$(echo "$input" | jq -r '.version // empty' | tr -d '\n\r')
VERSION_SEG=""
[ -n "$cc_version" ] && VERSION_SEG=" ${GRAY}v${cc_version}${RESET}"

# Effort level: prefer per-session stdin (.effort.level), fall back to settings.json
effort_level=$(echo "$input" | jq -r '.effort.level // empty' | tr -d '\n\r')
if [ -z "$effort_level" ]; then
    for settings_file in "$current_dir/.claude/settings.local.json" "$current_dir/.claude/settings.json" "$HOME/.claude/settings.json"; do
        if [ -f "$settings_file" ]; then
            val=$(jq -r '.effortLevel // empty' "$settings_file" 2>/dev/null | tr -d '\n\r')
            if [ -n "$val" ]; then
                effort_level="$val"
                break
            fi
        fi
    done
fi
EFFORT_SEG=""
if [ -n "$effort_level" ]; then
    case "$effort_level" in
        low)    effort_color="$GRAY" ;;
        medium) effort_color="$YELLOW" ;;
        high)   effort_color="$RED" ;;
        xhigh)  effort_color=$'\033[0;1;38;2;245;194;231m' ;;  # #f5c2e7 Pink
        max)    effort_color=$'\033[0;1;38;2;203;166;247m' ;;  # #cba6f7 Mauve (most intense)
        *)      effort_color="$GRAY" ;;
    esac
    EFFORT_SEG=" ${GRAY}(${effort_color}${effort_level}${GRAY})${RESET}"
fi

MODEL_SEG="${MODEL_COLOR}${model_display}${EFFORT_SEG}${VERSION_SEG}"

# === DIRECTORY display ===
if [[ "$current_dir" == "$HOME"* ]]; then
    display_dir="~${current_dir#$HOME}"
else
    display_dir="$current_dir"
fi
IFS='/' read -ra parts <<< "$display_dir"
num_parts=${#parts[@]}
if [ "$num_parts" -gt 4 ]; then
    display_dir="~/…/${parts[$((num_parts-2))]}/${parts[$((num_parts-1))]}"
fi
DIR_SEG="${DIR_COLOR}${display_dir}"

# === GIT ===
GIT_SEG=""
COMMIT_SEG=""
WORKTREE_SEG=""
if [ -d "$current_dir" ] && git -C "$current_dir" rev-parse --git-dir >/dev/null 2>&1; then
    git_branch=$(git -C "$current_dir" branch --show-current 2>/dev/null || echo "detached")
    [ -z "$git_branch" ] && git_branch="detached"

    # Worktree detection
    git_dir=$(git -C "$current_dir" rev-parse --git-dir 2>/dev/null)
    if [[ "$git_dir" == *"/worktrees/"* ]]; then
        worktree_name=$(basename "$git_dir")
        WORKTREE_SEG="${GRAY}wt ${YELLOW}${worktree_name}"
    fi

    git_status=$(git -C "$current_dir" status --porcelain 2>/dev/null)
    if [ -z "$git_status" ]; then
        status_icon="✓"
    elif echo "$git_status" | grep -qE "^(UU|AA|DD)" 2>/dev/null; then
        status_icon="⚠"
    else
        status_icon="●"
    fi

    ahead=$(git -C "$current_dir" rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
    behind=$(git -C "$current_dir" rev-list --count HEAD..@{u} 2>/dev/null || echo "0")

    git_extra=""
    [ "$ahead" -gt 0 ] 2>/dev/null && git_extra="${git_extra} ↑${ahead}"
    [ "$behind" -gt 0 ] 2>/dev/null && git_extra="${git_extra} ↓${behind}"

    if [ "$ahead" -eq 0 ] 2>/dev/null && [ "$behind" -eq 0 ] 2>/dev/null; then
        sync_icon=" ${ICON_SYNC}"
    else
        sync_icon=" ${ICON_DIVERGE}"
    fi

    GIT_SEG="${GIT_COLOR}${git_branch} ${status_icon}${sync_icon}${git_extra}"

    # Commit time
    last_commit_ts=$(git -C "$current_dir" log -1 --format=%ct 2>/dev/null)
    if [ -n "$last_commit_ts" ] && [ "$last_commit_ts" -gt 0 ] 2>/dev/null; then
        now=$(date +%s)
        diff_seconds=$((now - last_commit_ts))
        if [ "$diff_seconds" -lt 60 ]; then
            commit_ago="${diff_seconds}s"
        elif [ "$diff_seconds" -lt 3600 ]; then
            commit_ago="$((diff_seconds / 60))m"
        elif [ "$diff_seconds" -lt 86400 ]; then
            commit_ago="$((diff_seconds / 3600))h"
        else
            commit_ago="$((diff_seconds / 86400))d"
        fi
        COMMIT_SEG="${GRAY}${ICON_COMMIT} ${commit_ago}"
    fi
fi

# Line changes
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0' | tr -d '\n\r')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0' | tr -d '\n\r')
if [ "${lines_added:-0}" -gt 0 ] 2>/dev/null || [ "${lines_removed:-0}" -gt 0 ] 2>/dev/null; then
    line_changes=""
    [ "${lines_added:-0}" -gt 0 ] 2>/dev/null && line_changes="${line_changes} ${GREEN}+${lines_added}"
    [ "${lines_removed:-0}" -gt 0 ] 2>/dev/null && line_changes="${line_changes} ${RED}-${lines_removed}"
    [ -n "$GIT_SEG" ] && GIT_SEG="${GIT_SEG}${line_changes}"
fi

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

# === API USAGE ===
five_hour_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty | floor' | tr -d '\n\r')
resets_at_epoch=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty' | tr -d '\n\r')

USAGE_SEG=""
if [ -n "$five_hour_pct" ] && [ "$five_hour_pct" != "null" ]; then
    usage_icon=$(get_usage_icon "$five_hour_pct")

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

    USG_COLOR=$(get_pct_color "${five_hour_pct:-0}" "$USAGE_COLOR")
    USAGE_SEG="${GRAY}${usage_icon} ${USG_COLOR}${five_hour_pct}% ${GRAY}· ${reset_formatted}"
fi

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
    LINE1="${LINE1}${SEP}${GRAY}${duration_fmt}"
fi

LINE2="${DIR_SEG}"
[ -n "$GIT_SEG" ] && LINE2="${LINE2}${SEP}${GIT_SEG}"
[ -n "$WORKTREE_SEG" ] && LINE2="${LINE2}${SEP}${WORKTREE_SEG}"
[ -n "$COMMIT_SEG" ] && LINE2="${LINE2}${SEP}${COMMIT_SEG}"

printf '%s\n%s%s\n' "$LINE1" "$LINE2" "$RESET"
