#!/bin/bash
# Tim's Custom Statusline for Claude Code
# Uses new current_usage field from Claude Code 2.0.70+ for accurate context window percentage
# Includes visual progress bar and API usage tracking

# Read JSON input from stdin
input=$(cat)

# Colors (ANSI escape codes) - Vibrant RGB colors
RESET="\033[0m"
BOLD="\033[1m"
# Vibrant theme colors (true RGB)
MODEL_COLOR="\033[1;38;2;217;120;87m"     # #D97857
DIR_ICON_COLOR="\033[1;38;2;229;192;123m"  # #E5C07B (Atom yellow)
DIR_TEXT_COLOR="\033[1;38;2;35;207;136m"   # #23CF88 green
CONTEXT_COLOR="\033[1;38;2;97;175;239m"    # #61AFEF (Atom blue)
GIT_COLOR="\033[1;38;2;209;154;102m"       # #D19A66 (Atom orange)
USAGE_COLOR="\033[1;38;2;198;120;221m"     # #C678DD (Atom magenta)
SESSION_COLOR="\033[1;38;2;152;195;121m"   # #98C379 (Atom green)
TIME_COLOR="\033[1;38;2;86;182;194m"       # #56B6C2 (Atom cyan)
# Utility colors
GRAY="\033[1;38;2;128;128;128m"
GREEN="\033[1;38;2;152;195;121m"           # #98C379 (Atom green)
YELLOW="\033[1;38;2;229;192;123m"          # #E5C07B (Atom yellow)
RED="\033[1;38;2;224;108;117m"             # #E06C75 (Atom red)
DIM="\033[2m"

# Nerd Font Icons (from CCometixLine)
ICON_MODEL="✳"
ICON_FOLDER="󰉋"
ICON_GIT="󰊢"
ICON_CONTEXT="󱘲"
ICON_TIME="󱦻"
ICON_COMMIT="󰜘"

# Circle slice icons for usage percentage
get_circle_icon() {
    local pct=$1
    if [ "$pct" -le 12 ]; then echo "󰪞"
    elif [ "$pct" -le 25 ]; then echo "󰪟"
    elif [ "$pct" -le 37 ]; then echo "󰪠"
    elif [ "$pct" -le 50 ]; then echo "󰪡"
    elif [ "$pct" -le 62 ]; then echo "󰪢"
    elif [ "$pct" -le 75 ]; then echo "󰪣"
    elif [ "$pct" -le 87 ]; then echo "󰪤"
    else echo "󰪥"
    fi
}

# Separator
SEP="${GRAY} | ${RESET}"

# === MODEL SEGMENT ===
model_display=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
case "$model_display" in
    *"Opus"*) model_display="Opus 4.5" ;;
    *"Sonnet"*) model_display="Sonnet 4" ;;
    *"Haiku"*) model_display="Haiku" ;;
esac
MODEL_SEG="${BOLD}${MODEL_COLOR}${ICON_MODEL}${RESET} ${MODEL_COLOR}${model_display}${RESET}"

# === DIRECTORY SEGMENT (shortened: ~/…/parent/folder) ===
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // "/"')
# Replace home dir with ~
if [[ "$current_dir" == "$HOME"* ]]; then
    display_dir="~${current_dir#$HOME}"
else
    display_dir="$current_dir"
fi
# Shorten to ~/…/parent/folder if more than 4 levels deep
IFS='/' read -ra parts <<< "$display_dir"
num_parts=${#parts[@]}
if [ "$num_parts" -gt 4 ]; then
    parent="${parts[$((num_parts-2))]}"
    folder="${parts[$((num_parts-1))]}"
    display_dir="~/…/${parent}/${folder}"
fi
DIR_SEG="${DIR_ICON_COLOR}${ICON_FOLDER}${RESET} ${GRAY}${display_dir}${RESET}"

# === GIT SEGMENT ===
GIT_SEG=""
if git -C "$current_dir" rev-parse --git-dir >/dev/null 2>&1; then
    # Get branch name
    git_branch=$(git -C "$current_dir" branch --show-current 2>/dev/null)
    if [ -z "$git_branch" ]; then
        git_branch="detached"
    fi

    # Get status (clean/dirty)
    git_status=$(git -C "$current_dir" status --porcelain 2>/dev/null)
    if [ -z "$git_status" ]; then
        status_icon="✓"
    elif echo "$git_status" | grep -qE "^(UU|AA|DD)"; then
        status_icon="⚠"
    else
        status_icon="●"
    fi

    # Get ahead/behind and sync status
    ahead=$(git -C "$current_dir" rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
    behind=$(git -C "$current_dir" rev-list --count HEAD..@{u} 2>/dev/null || echo "0")

    git_extra=""
    [ "$ahead" -gt 0 ] 2>/dev/null && git_extra="${git_extra} ↑${ahead}"
    [ "$behind" -gt 0 ] 2>/dev/null && git_extra="${git_extra} ↓${behind}"

    # Remote sync icon
    if [ "$ahead" -eq 0 ] && [ "$behind" -eq 0 ]; then
        sync_icon=" 󰓦"  # synced
    else
        sync_icon=" 󰓧"  # diverged
    fi

    GIT_SEG="${GIT_COLOR}${ICON_GIT}${RESET} ${GIT_COLOR}${git_branch} ${status_icon}${sync_icon}${git_extra}${RESET}"

    # Get last commit time
    last_commit_ts=$(git -C "$current_dir" log -1 --format=%ct 2>/dev/null)
    if [ -n "$last_commit_ts" ]; then
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
        COMMIT_SEG="${GRAY}${ICON_COMMIT}${RESET} ${GRAY}${commit_ago}${RESET}"
    fi
fi

# Get line changes for git segment
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
line_changes=""
if [ "$lines_added" -gt 0 ] || [ "$lines_removed" -gt 0 ]; then
    if [ "$lines_added" -gt 0 ] && [ "$lines_removed" -gt 0 ]; then
        line_changes=" ${GREEN}+${lines_added}${RESET} ${RED}-${lines_removed}${RESET}"
    elif [ "$lines_added" -gt 0 ]; then
        line_changes=" ${GREEN}+${lines_added}${RESET}"
    else
        line_changes=" ${RED}-${lines_removed}${RESET}"
    fi
    # Append to git segment if it exists
    if [ -n "$GIT_SEG" ]; then
        GIT_SEG="${GIT_SEG}${line_changes}"
    fi
fi

# === CONTEXT WINDOW SEGMENT (minimal) ===
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
input_tokens=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
output_tokens=$(echo "$input" | jq -r '.context_window.current_usage.output_tokens // 0')
cache_creation=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')

total_tokens=$((input_tokens + output_tokens + cache_creation + cache_read))

if [ "$total_tokens" -eq 0 ]; then
    total_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
fi

if [ "$context_size" -gt 0 ] && [ "$total_tokens" -gt 0 ]; then
    pct_display=$(awk "BEGIN {printf \"%.0f\", ($total_tokens / $context_size) * 100}")
    # Format tokens (e.g., 122k)
    if [ "$total_tokens" -ge 1000 ]; then
        tokens_display=$(awk "BEGIN {printf \"%.1fk\", $total_tokens / 1000}")
    else
        tokens_display="$total_tokens"
    fi
    CONTEXT_SEG="${CONTEXT_COLOR}${ICON_CONTEXT}${RESET} ${CONTEXT_COLOR}${pct_display}% · ${tokens_display}${RESET}"
else
    CONTEXT_SEG="${CONTEXT_COLOR}${ICON_CONTEXT}${RESET} ${CONTEXT_COLOR}0%${RESET}"
fi

# === API USAGE SEGMENT (from Anthropic API) ===
CACHE_FILE="$HOME/.claude/statusline_usage_cache.json"
CACHE_DURATION=60  # 1 minute

# Function to get OAuth token from Claude credentials (macOS Keychain first, then file)
get_oauth_token() {
    # Try macOS Keychain first (use service name only, let security find the account)
    local keychain_data=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)

    if [ -n "$keychain_data" ]; then
        local token=$(echo "$keychain_data" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
        if [ -n "$token" ]; then
            echo "$token"
            return
        fi
    fi

    # Fallback to file
    local creds_file="$HOME/.claude/.credentials.json"
    if [ -f "$creds_file" ]; then
        jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null
    fi
}

# Function to fetch API usage
fetch_api_usage() {
    local token=$(get_oauth_token)
    if [ -z "$token" ]; then
        return 1
    fi

    local response=$(curl -s --max-time 2 \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

    if [ -n "$response" ] && echo "$response" | jq -e '.five_hour' >/dev/null 2>&1; then
        local five_hour=$(echo "$response" | jq -r '.five_hour.utilization // 0')
        local resets_at=$(echo "$response" | jq -r '.five_hour.resets_at // ""')

        # Cache the result
        echo "{\"five_hour\": $five_hour, \"resets_at\": \"$resets_at\", \"cached_at\": $(date +%s)}" > "$CACHE_FILE"
        echo "$five_hour|$resets_at"
        return 0
    fi
    return 1
}

# Get usage (from cache or API)
get_usage() {
    # Check cache first
    if [ -f "$CACHE_FILE" ]; then
        local cached_at=$(jq -r '.cached_at // 0' "$CACHE_FILE" 2>/dev/null)
        local now=$(date +%s)
        local age=$((now - cached_at))

        if [ "$age" -lt "$CACHE_DURATION" ]; then
            local five_hour=$(jq -r '.five_hour // 0' "$CACHE_FILE")
            local resets_at=$(jq -r '.resets_at // ""' "$CACHE_FILE")
            echo "$five_hour|$resets_at"
            return 0
        fi
    fi

    # Fetch fresh data
    fetch_api_usage
}

usage_data=$(get_usage)
if [ -n "$usage_data" ]; then
    five_hour_pct=$(echo "$usage_data" | cut -d'|' -f1)
    resets_at=$(echo "$usage_data" | cut -d'|' -f2)

    # Round percentage
    five_hour_int=$(awk "BEGIN {printf \"%.0f\", $five_hour_pct}")

    # Format reset time (dd-MM hh:mm) with timezone conversion
    if [ -n "$resets_at" ] && [ "$resets_at" != "null" ] && [ "$resets_at" != "" ]; then
        clean_date="${resets_at%%.*}"
        unix_ts=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$clean_date" "+%s" 2>/dev/null)
        if [ -n "$unix_ts" ]; then
            reset_formatted=$(date -j -f "%s" "$unix_ts" "+%d-%m %H:%M" 2>/dev/null || echo "?")
        else
            reset_formatted="?"
        fi
    else
        reset_formatted="?"
    fi

    # Get dynamic circle icon
    USAGE_ICON=$(get_circle_icon "$five_hour_int")
    USAGE_SEG="${USAGE_COLOR}${USAGE_ICON}${RESET} ${USAGE_COLOR}${five_hour_int}% · ${reset_formatted}${RESET}"
else
    USAGE_SEG="${USAGE_COLOR}󰪞${RESET} ${USAGE_COLOR}?%${RESET}"
fi

# === SESSION TIME SEGMENT ===
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')

if [ "$duration_ms" -gt 0 ]; then
    total_seconds=$((duration_ms / 1000))

    if [ "$total_seconds" -ge 3600 ]; then
        hours=$((total_seconds / 3600))
        minutes=$(((total_seconds % 3600) / 60))
        time_display="${hours}h${minutes}m"
    elif [ "$total_seconds" -ge 60 ]; then
        minutes=$((total_seconds / 60))
        seconds=$((total_seconds % 60))
        time_display="${minutes}m${seconds}s"
    else
        time_display="${total_seconds}s"
    fi
else
    time_display="0s"
fi

TIME_SEG="${TIME_COLOR}${ICON_TIME}${RESET} ${TIME_COLOR}${time_display}${RESET}"

# === OUTPUT ===
# Build output: Line 1 = stats, Line 2 = dir + git + commit
LINE1="${MODEL_SEG}${SEP}${CONTEXT_SEG}${SEP}${USAGE_SEG}${SEP}${TIME_SEG}"
if [ -n "$GIT_SEG" ]; then
    LINE2="${DIR_SEG}${SEP}${GIT_SEG}"
    if [ -n "$COMMIT_SEG" ]; then
        LINE2="${LINE2}${SEP}${COMMIT_SEG}"
    fi
else
    LINE2="${DIR_SEG}"
fi
echo -e "${LINE1}\n${LINE2}"
