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

# Icons - korte afkortingen met :
ICON_MODEL=""
ICON_FOLDER=""
ICON_GIT=""
ICON_CONTEXT="ctx"
ICON_TIME=""
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

# Dynamic circle icon for usage (iTerm only)
get_usage_icon() {
    local pct=$1
    if [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
        if [ "$pct" -le 12 ]; then echo "󰪞"
        elif [ "$pct" -le 25 ]; then echo "󰪟"
        elif [ "$pct" -le 37 ]; then echo "󰪠"
        elif [ "$pct" -le 50 ]; then echo "󰪡"
        elif [ "$pct" -le 62 ]; then echo "󰪢"
        elif [ "$pct" -le 75 ]; then echo "󰪣"
        elif [ "$pct" -le 87 ]; then echo "󰪤"
        else echo "󰪥"
        fi
    else
        echo "$ICON_USAGE"
    fi
}

SEP="${GRAY} | "

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

# === DIRECTORY ===
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // "/"' | tr -d '\n\r')
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
CTX_CACHE_FILE="$HOME/.claude/statusline_ctx_cache.json"

# Use used_percentage from Claude Code v2.1.6+ (matches /context command)
# ctx_size already read in MODEL section
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty | floor' | tr -d '\n\r')

if [ -n "$used_pct" ] && [ "$used_pct" != "null" ] && [ "$used_pct" != "" ]; then
    used_tokens=$((ctx_size * used_pct / 100))
    used_k=$((used_tokens / 1000))
    CTX_COLOR=$(get_pct_color "$used_pct" "$CONTEXT_COLOR")
    # Cache valid context data
    echo "{\"pct\": $used_pct, \"tokens\": \"${used_k}k\", \"cached_at\": $(date +%s)}" > "$CTX_CACHE_FILE" 2>/dev/null
    CONTEXT_SEG="${GRAY}${ICON_CONTEXT} ${CTX_COLOR}${used_pct}% ${GRAY}· ${used_k}k"
else
    # Try to use cached context data
    if [ -f "$CTX_CACHE_FILE" ]; then
        cached_pct=$(jq -r '.pct // 0' "$CTX_CACHE_FILE" 2>/dev/null | tr -d '\n\r')
        cached_tokens=$(jq -r '.tokens // "0"' "$CTX_CACHE_FILE" 2>/dev/null | tr -d '\n\r')
        CTX_COLOR=$(get_pct_color "${cached_pct:-0}" "$CONTEXT_COLOR")
        CONTEXT_SEG="${GRAY}${ICON_CONTEXT} ${CTX_COLOR}${cached_pct:-0}% ${GRAY}· ${cached_tokens}"
    else
        CONTEXT_SEG="${GRAY}${ICON_CONTEXT} ${CONTEXT_COLOR}0%"
    fi
fi

# === API USAGE ===
CACHE_FILE="$HOME/.claude/statusline_usage_cache.json"

USAGE_CACHE_TTL=300  # 5 minutes — API has aggressive rate limits (~5 req/token)

get_cached_usage() {
    if [ -f "$CACHE_FILE" ]; then
        local cached_at=$(jq -r '.cached_at // 0' "$CACHE_FILE" 2>/dev/null | tr -d '\n\r')
        local now=$(date +%s)
        local age=$((now - cached_at))
        local data=$(jq -r '"\(.five_hour // 0)|\(.resets_at // "")"' "$CACHE_FILE" 2>/dev/null | tr -d '\n\r')
        if [ -n "$data" ] && [ "$data" != "|" ]; then
            echo "$data"
            [ "$age" -lt "$USAGE_CACHE_TTL" ] && return 0 || return 1
        fi
    fi
    return 2  # No cache at all
}

fetch_usage_background() {
    # Prevent concurrent fetches with a lock file
    local LOCK_FILE="$HOME/.claude/statusline_usage.lock"
    if [ -f "$LOCK_FILE" ]; then
        local lock_age=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0) ))
        [ "$lock_age" -lt 30 ] && return 0  # Another fetch is running
    fi
    (
        touch "$LOCK_FILE"
        trap 'rm -f "$LOCK_FILE"' EXIT

        local token=""
        local keychain_data=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
        if [ -n "$keychain_data" ]; then
            token=$(echo "$keychain_data" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null | tr -d '\n\r')
        fi
        if [ -z "$token" ] && [ -f "$HOME/.claude/.credentials.json" ]; then
            token=$(jq -r '.claudeAiOauth.accessToken // empty' "$HOME/.claude/.credentials.json" 2>/dev/null | tr -d '\n\r')
        fi
        [ -z "$token" ] && exit 0

        local http_code response
        response=$(curl -s --max-time 5 -w "\n%{http_code}" \
            -H "Authorization: Bearer $token" \
            -H "anthropic-beta: oauth-2025-04-20" \
            "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

        http_code=$(echo "$response" | tail -1)
        response=$(echo "$response" | sed '$d')

        if [ "$http_code" = "429" ]; then
            # Rate limited — extend cache TTL by touching cached_at
            if [ -f "$CACHE_FILE" ]; then
                local existing=$(cat "$CACHE_FILE")
                echo "$existing" | jq --arg ts "$(date +%s)" '.cached_at = ($ts | tonumber)' > "$CACHE_FILE" 2>/dev/null
            fi
            exit 0
        fi

        if [ -n "$response" ] && echo "$response" | jq -e '.five_hour' >/dev/null 2>&1; then
            local five_hour=$(echo "$response" | jq -r '.five_hour.utilization // 0' | tr -d '\n\r')
            local resets_at=$(echo "$response" | jq -r '.five_hour.resets_at // ""' | tr -d '\n\r')
            echo "{\"five_hour\": $five_hour, \"resets_at\": \"$resets_at\", \"cached_at\": $(date +%s)}" > "$CACHE_FILE"
        fi
    ) >/dev/null 2>&1 &
}

usage_data=$(get_cached_usage)
cache_status=$?
# 0=fresh, 1=stale (refresh in background), 2=no cache
if [ "$cache_status" -eq 1 ]; then
    fetch_usage_background
elif [ "$cache_status" -eq 2 ]; then
    fetch_usage_background
    usage_data="0|"
fi

five_hour_pct=$(echo "$usage_data" | cut -d'|' -f1)
resets_at=$(echo "$usage_data" | cut -d'|' -f2)
five_hour_int=$(awk "BEGIN {printf \"%.0f\", ${five_hour_pct:-0}}" 2>/dev/null || echo "0")

reset_formatted="?"
if [ -n "$resets_at" ] && [ "$resets_at" != "null" ] && [ "$resets_at" != "" ]; then
    clean_date="${resets_at%%.*}"
    unix_ts=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$clean_date" "+%s" 2>/dev/null)
    if [ -n "$unix_ts" ]; then
        today=$(date "+%Y-%m-%d")
        reset_day=$(date -j -f "%s" "$unix_ts" "+%Y-%m-%d" 2>/dev/null)
        if [ "$today" = "$reset_day" ]; then
            reset_formatted=$(date -j -f "%s" "$unix_ts" "+%H:%M" 2>/dev/null || echo "?")
        else
            reset_formatted=$(date -j -f "%s" "$unix_ts" "+%d-%m %H:%M" 2>/dev/null || echo "?")
        fi
    fi
fi

USG_COLOR=$(get_pct_color "${five_hour_int:-0}" "$USAGE_COLOR")
USAGE_SEG="${GRAY}${ICON_USAGE} ${USG_COLOR}${five_hour_int:-0}% ${GRAY}· ${reset_formatted}"

# === OUTPUT (2 lines) ===
LINE1="${MODEL_SEG}${SEP}${CONTEXT_SEG}${SEP}${USAGE_SEG}"
LINE2="${DIR_SEG}"
[ -n "$GIT_SEG" ] && LINE2="${LINE2}${SEP}${GIT_SEG}"
[ -n "$WORKTREE_SEG" ] && LINE2="${LINE2}${SEP}${WORKTREE_SEG}"
[ -n "$COMMIT_SEG" ] && LINE2="${LINE2}${SEP}${COMMIT_SEG}"

printf '%s\n%s%s\n' "$LINE1" "$LINE2" "$RESET"
