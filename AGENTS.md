# statusline-claudecode-tim

Custom two-line Claude Code statusline in `statusline-tim.sh` (bash, true-color Catppuccin Mocha, no Nerd Font icons so it renders in VS Code). Claude Code pipes session JSON on stdin; the script prints the statusline.

- Test: `./statusline-tim.sh < example.json`. Update `example.json` when you rely on new stdin fields.
- Install: point `statusLine.command` in `~/.claude/settings.json` at this script.
