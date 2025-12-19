#!/bin/bash
# Tim's Custom Statusline for Claude Code
# 256-color, 2 lines, NO Nerd Font icons (VS Code compatible)

exec 2>/dev/null

input=$(cat)

# Colors (256-color Atom One Dark theme)
RESET=$'\033[0m'
MODEL_COLOR=$'\033[1;38;5;173m'     # #D97857 rust orange
DIR_COLOR=$'\033[1;38;5;114m'       # #98C379 Atom green
CONTEXT_COLOR=$'\033[1;38;5;111m'   # #61AFEF Atom blue
GIT_COLOR=$'\033[1;38;5;180m'       # #D19A66 Atom orange
USAGE_COLOR=$'\033[1;38;5;176m'     # #C678DD Atom magenta
TIME_COLOR=$'\033[1;38;5;80m'       # #56B6C2 Atom cyan
GRAY=$'\033[38;5;244m'              # Gray for labels
GREEN=$'\033[1;38;5;114m'           # #98C379 Atom green
YELLOW=$'\033[1;38;5;179m'          # #E5C07B Atom yellow
RED=$'\033[1;38;5;167m'             # #E06C75 Atom red

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

SEP="${GRAY} | ${RESET}"

# === MODEL ===
model_display=$(echo "$input" | jq -r '.model.display_name // "Unknown"' | tr -d '\n\r')
case "$model_display" in
    *"Opus"*) model_display="Opus 4.5" ;;
    *"Sonnet"*) model_display="Sonnet 4" ;;
    *"Haiku"*) model_display="Haiku" ;;
esac
MODEL_SEG="${MODEL_COLOR}${model_display}${RESET}"

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
DIR_SEG="${DIR_COLOR}${display_dir}${RESET}"

# === GIT ===
GIT_SEG=""
COMMIT_SEG=""
if [ -d "$current_dir" ] && git -C "$current_dir" rev-parse --git-dir >/dev/null 2>&1; then
    git_branch=$(git -C "$current_dir" branch --show-current 2>/dev/null || echo "detached")
    [ -z "$git_branch" ] && git_branch="detached"

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

    GIT_SEG="${GIT_COLOR}${git_branch} ${status_icon}${sync_icon}${git_extra}${RESET}"

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
        COMMIT_SEG="${GRAY}${ICON_COMMIT} ${commit_ago}${RESET}"
    fi
fi

# Line changes
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0' | tr -d '\n\r')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0' | tr -d '\n\r')
if [ "${lines_added:-0}" -gt 0 ] 2>/dev/null || [ "${lines_removed:-0}" -gt 0 ] 2>/dev/null; then
    line_changes=""
    [ "${lines_added:-0}" -gt 0 ] 2>/dev/null && line_changes="${line_changes} ${GREEN}+${lines_added}${RESET}"
    [ "${lines_removed:-0}" -gt 0 ] 2>/dev/null && line_changes="${line_changes} ${RED}-${lines_removed}${RESET}"
    [ -n "$GIT_SEG" ] && GIT_SEG="${GIT_SEG}${line_changes}"
fi

# === CONTEXT ===
CTX_CACHE_FILE="$HOME/.claude/statusline_ctx_cache.json"

context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000' | tr -d '\n\r')
input_tokens=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0' | tr -d '\n\r')
output_tokens=$(echo "$input" | jq -r '.context_window.current_usage.output_tokens // 0' | tr -d '\n\r')
cache_creation=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0' | tr -d '\n\r')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0' | tr -d '\n\r')

total_tokens=$((input_tokens + output_tokens + cache_creation + cache_read))
[ "$total_tokens" -eq 0 ] && total_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0' | tr -d '\n\r')

if [ "${context_size:-0}" -gt 0 ] 2>/dev/null && [ "${total_tokens:-0}" -gt 0 ] 2>/dev/null; then
    pct_display=$(awk "BEGIN {printf \"%.0f\", ($total_tokens / $context_size) * 100}")
    CTX_COLOR=$(get_pct_color "$pct_display" "$CONTEXT_COLOR")
    if [ "$total_tokens" -ge 1000 ]; then
        tokens_display=$(awk "BEGIN {printf \"%.1fk\", $total_tokens / 1000}")
    else
        tokens_display="$total_tokens"
    fi
    # Cache valid context data
    echo "{\"pct\": $pct_display, \"tokens\": \"$tokens_display\", \"cached_at\": $(date +%s)}" > "$CTX_CACHE_FILE" 2>/dev/null
    CONTEXT_SEG="${GRAY}${ICON_CONTEXT}${RESET} ${CTX_COLOR}${pct_display}% · ${tokens_display}${RESET}"
else
    # Try to use cached context data
    if [ -f "$CTX_CACHE_FILE" ]; then
        cached_pct=$(jq -r '.pct // 0' "$CTX_CACHE_FILE" 2>/dev/null | tr -d '\n\r')
        cached_tokens=$(jq -r '.tokens // "0"' "$CTX_CACHE_FILE" 2>/dev/null | tr -d '\n\r')
        CTX_COLOR=$(get_pct_color "${cached_pct:-0}" "$CONTEXT_COLOR")
        CONTEXT_SEG="${GRAY}${ICON_CONTEXT}${RESET} ${CTX_COLOR}${cached_pct:-0}% · ${cached_tokens}${RESET}"
    else
        CONTEXT_SEG="${GRAY}${ICON_CONTEXT}${RESET} ${CONTEXT_COLOR}0%${RESET}"
    fi
fi

# === API USAGE ===
CACHE_FILE="$HOME/.claude/statusline_usage_cache.json"

get_cached_usage() {
    if [ -f "$CACHE_FILE" ]; then
        local cached_at=$(jq -r '.cached_at // 0' "$CACHE_FILE" 2>/dev/null | tr -d '\n\r')
        local now=$(date +%s)
        local age=$((now - cached_at))
        # Always return cached data if available
        local data=$(jq -r '"\(.five_hour // 0)|\(.resets_at // "")"' "$CACHE_FILE" 2>/dev/null | tr -d '\n\r')
        if [ -n "$data" ] && [ "$data" != "|" ]; then
            echo "$data"
            # Return 0 if fresh, 1 if stale (needs refresh)
            [ "$age" -lt 60 ] && return 0 || return 1
        fi
    fi
    return 2  # No cache at all
}

fetch_usage_background() {
    (
        local token=""
        local keychain_data=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
        if [ -n "$keychain_data" ]; then
            token=$(echo "$keychain_data" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null | tr -d '\n\r')
        fi
        if [ -z "$token" ] && [ -f "$HOME/.claude/.credentials.json" ]; then
            token=$(jq -r '.claudeAiOauth.accessToken // empty' "$HOME/.claude/.credentials.json" 2>/dev/null | tr -d '\n\r')
        fi
        [ -z "$token" ] && exit 0

        local response=$(curl -s --max-time 2 \
            -H "Authorization: Bearer $token" \
            -H "anthropic-beta: oauth-2025-04-20" \
            "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

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
    [ -n "$unix_ts" ] && reset_formatted=$(date -j -f "%s" "$unix_ts" "+%d-%m %H:%M" 2>/dev/null || echo "?")
fi

USG_COLOR=$(get_pct_color "${five_hour_int:-0}" "$USAGE_COLOR")
USAGE_SEG="${GRAY}${ICON_USAGE}${RESET} ${USG_COLOR}${five_hour_int:-0}% · ${reset_formatted}${RESET}"

# === SESSION TIME ===
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0' | tr -d '\n\r')
if [ "${duration_ms:-0}" -gt 0 ] 2>/dev/null; then
    total_seconds=$((duration_ms / 1000))
    if [ "$total_seconds" -ge 3600 ]; then
        time_display="$((total_seconds / 3600))h$(((total_seconds % 3600) / 60))m"
    elif [ "$total_seconds" -ge 60 ]; then
        time_display="$((total_seconds / 60))m$((total_seconds % 60))s"
    else
        time_display="${total_seconds}s"
    fi
else
    time_display="0s"
fi
TIME_SEG="${TIME_COLOR}${time_display}${RESET}"

# === OUTPUT (2 lines) ===
LINE1="${MODEL_SEG}${SEP}${CONTEXT_SEG}${SEP}${USAGE_SEG}${SEP}${TIME_SEG}"
LINE2="${DIR_SEG}"
[ -n "$GIT_SEG" ] && LINE2="${LINE2}${SEP}${GIT_SEG}"
[ -n "$COMMIT_SEG" ] && LINE2="${LINE2}${SEP}${COMMIT_SEG}"

printf '%s\n%s\n' "$LINE1" "$LINE2"
