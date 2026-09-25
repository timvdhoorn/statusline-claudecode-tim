#!/bin/bash
# Tim's Custom Statusline for Claude Code
# 256-color, 2 lines, NO Nerd Font icons (VS Code compatible)

exec 2>/dev/null

input=$(cat)

# Colors (true-color Catppuccin Mocha theme)
# Each color includes reset (0;) to atomically switch — prevents color bleed from Claude Code UI
RESET=$'\033[0m'
MODEL_COLOR=$'\033[0;1;38;2;205;214;244m'   # #cdd6f4 Text (model = neutral anchor)
DIR_COLOR=$'\033[0;38;2;127;132;156m'       # #7f849c Gray (path = neutral)
CONTEXT_COLOR=$'\033[0;1;38;2;137;180;250m' # #89b4fa Blue
GIT_COLOR=$'\033[0;1;38;2;203;166;247m'     # #cba6f7 Mauve
USAGE_COLOR=$'\033[0;1;38;2;203;166;247m'   # #cba6f7 Mauve
GRAY=$'\033[0;38;2;127;132;156m'            # #7f849c Overlay1
GREEN=$'\033[0;1;38;2;166;227;161m'         # #a6e3a1 Green
YELLOW=$'\033[0;1;38;2;249;226;175m'        # #f9e2af Yellow
PEACH=$'\033[0;1;38;2;250;179;135m'         # #fab387 Peach
MAROON=$'\033[0;1;38;2;235;160;172m'        # #eba0ac Maroon
RED=$'\033[0;1;38;2;243;139;168m'           # #f38ba8 Red

# Icons
ICON_CONTEXT="ctx"
ICON_USAGE="5h"
ICON_WEEK="wk"
ICON_COMMIT="cmt"
ICON_SYNC="ok"
ICON_DIVERGE="!!"

# Context fill color — 5-band ramp on percentage (scales per model: 1M green<200k=20%, 200k green<40k=20%).
get_ctx_color() {
    local pct=$1
    if   [ "$pct" -lt 20 ]; then echo "$GREEN"
    elif [ "$pct" -lt 40 ]; then echo "$YELLOW"
    elif [ "$pct" -lt 60 ]; then echo "$PEACH"
    elif [ "$pct" -lt 80 ]; then echo "$MAROON"
    else echo "$RED"
    fi
}

# Format epoch seconds; BSD date on macOS, GNU date on Linux.
fmt_epoch() {
    date -j -f "%s" "$1" "$2" 2>/dev/null || date -d "@$1" "$2" 2>/dev/null
}

# Rate-limit fill color — milder ramp (5h/wk reset slowly, warn late).
get_usage_color() {
    local pct=$1
    if   [ "$pct" -lt 60 ]; then echo "$GREEN"
    elif [ "$pct" -lt 80 ]; then echo "$YELLOW"
    elif [ "$pct" -lt 90 ]; then echo "$PEACH"
    else echo "$RED"
    fi
}

# Rainbow text — color each char across the spectrum (for effort level "max").
rainbow_text() {
    local text=$1
    local palette=(
        '38;2;243;139;168'  # red
        '38;2;250;179;135'  # peach
        '38;2;249;226;175'  # yellow
        '38;2;166;227;161'  # green
        '38;2;137;220;235'  # sky
        '38;2;137;180;250'  # blue
        '38;2;203;166;247'  # mauve
    )
    local out="" i ch n=${#palette[@]}
    for ((i = 0; i < ${#text}; i++)); do
        ch=${text:i:1}
        out+=$'\033['"0;1;${palette[i % n]}m${ch}"
    done
    printf '%s' "$out"
}

# Smooth N-cell progress bar with eighth-block sub-cell fill (4 cells = 32 steps).
# Uses Unicode block elements only (VS Code compatible, no Nerd Font).
build_bar() {
    local pct=$1
    local cells=6
    local partials=(' ' '▏' '▎' '▍' '▌' '▋' '▊' '▉')
    local eighths=$(( (pct * cells * 8 + 50) / 100 ))
    local full=$(( eighths / 8 ))
    local rem=$(( eighths % 8 ))
    local bar="" i
    for ((i = 0; i < full; i++)); do bar="${bar}█"; done
    [ "$rem" -gt 0 ] && bar="${bar}${partials[$rem]}"
    local used=$(( full + (rem > 0 ? 1 : 0) ))
    for ((i = used; i < cells; i++)); do bar="${bar} "; done
    printf '%s' "$bar"
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
    # Colors aligned with Claude Code effort levels.
    case "$effort_level" in
        low)       effort_disp="${YELLOW}${effort_level}" ;;                        # geel
        medium)    effort_disp="${GREEN}${effort_level}" ;;                         # groen
        high)      effort_disp=$'\033[0;1;38;2;137;220;235m'"${effort_level}" ;;    # #89dceb Sky (lichtblauw)
        xhigh)     effort_disp=$'\033[0;1;38;2;180;190;254m'"${effort_level}" ;;    # #b4befe Lavender (lichtpaars)
        max)       effort_disp=$(rainbow_text "$effort_level") ;;                   # regenboog
        ultracode) effort_disp=$'\033[0;1;38;2;136;57;239m'"${effort_level}" ;;     # #8839ef donkerpaars
        *)         effort_disp="${GRAY}${effort_level}" ;;
    esac
    EFFORT_SEG=" ${GRAY}(${effort_disp}${GRAY})${RESET}"
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
    CTX_COLOR=$(get_ctx_color "$used_pct")
    ctx_bar=$(build_bar "$used_pct")
    CONTEXT_SEG="${GRAY}${ICON_CONTEXT} ▕${CTX_COLOR}${ctx_bar}${GRAY}▏${CTX_COLOR}${used_pct}% ${GRAY}· ${used_k}k"
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
            reset_day=$(fmt_epoch "$resets_at_int" "+%Y-%m-%d")
            if [ "$today" = "$reset_day" ]; then
                reset_formatted=$(fmt_epoch "$resets_at_int" "+%H:%M" || echo "?")
            else
                reset_formatted=$(fmt_epoch "$resets_at_int" "+%d-%m %H:%M" || echo "?")
            fi
        fi
    fi

    USG_COLOR=$(get_usage_color "${five_hour_pct:-0}")
    USAGE_SEG="${GRAY}${usage_icon} ${USG_COLOR}${five_hour_pct}% ${GRAY}· ${reset_formatted}"
fi

# === WEEKLY USAGE ===
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // .rate_limits.weekly.used_percentage // empty | floor' | tr -d '\n\r')
week_resets_at=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // .rate_limits.weekly.resets_at // empty' | tr -d '\n\r')

WEEK_SEG=""
if [ -n "$week_pct" ] && [ "$week_pct" != "null" ]; then
    week_reset_formatted="?"
    if [ -n "$week_resets_at" ] && [ "$week_resets_at" != "null" ]; then
        week_resets_int=$(awk "BEGIN {printf \"%.0f\", $week_resets_at}" 2>/dev/null)
        if [ -n "$week_resets_int" ]; then
            today=$(date "+%Y-%m-%d")
            week_reset_day=$(fmt_epoch "$week_resets_int" "+%Y-%m-%d")
            if [ "$today" = "$week_reset_day" ]; then
                week_reset_formatted=$(fmt_epoch "$week_resets_int" "+%H:%M" || echo "?")
            else
                week_reset_formatted=$(fmt_epoch "$week_resets_int" "+%d-%m %H:%M" || echo "?")
            fi
        fi
    fi

    WK_COLOR=$(get_usage_color "${week_pct:-0}")
    WEEK_SEG="${GRAY}${ICON_WEEK} ${WK_COLOR}${week_pct}% ${GRAY}· ${week_reset_formatted}"
fi

# === OUTPUT (2 lines) ===
LINE1="${MODEL_SEG}"
[ -n "$CONTEXT_SEG" ] && LINE1="${LINE1}${SEP}${CONTEXT_SEG}"
[ -n "$USAGE_SEG" ] && LINE1="${LINE1}${SEP}${USAGE_SEG}"
[ -n "$WEEK_SEG" ] && LINE1="${LINE1}${SEP}${WEEK_SEG}"

LINE2="${DIR_SEG}"
[ -n "$GIT_SEG" ] && LINE2="${LINE2}${SEP}${GIT_SEG}"
[ -n "$WORKTREE_SEG" ] && LINE2="${LINE2}${SEP}${WORKTREE_SEG}"
[ -n "$COMMIT_SEG" ] && LINE2="${LINE2}${SEP}${COMMIT_SEG}"

printf '%s\n%s%s\n' "$LINE1" "$LINE2" "$RESET"
