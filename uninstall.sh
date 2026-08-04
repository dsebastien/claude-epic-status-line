#!/usr/bin/env bash
# Usage: ./uninstall.sh [--purge]
#   --purge  also delete ~/.config/claude-epic-status-line (your customizations)
set -euo pipefail

DEST="$HOME/.claude/statusline-command.sh"
SETTINGS="$HOME/.claude/settings.json"
CONFIG_DIR="$HOME/.config/claude-epic-status-line"
CACHE_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/claude-statusline-$(id -u)"

# Remove statusline script
if [ -f "$DEST" ]; then
    rm "$DEST"
    echo "Removed $DEST"
fi

# Restore backup if available
restored=false
if [ -f "${DEST}.bak" ]; then
    mv "${DEST}.bak" "$DEST"
    restored=true
    echo "Restored previous statusline from backup"
fi

# Settings: keep the wiring when a previous script was restored (it lives at
# the same path); otherwise remove the statusLine key — loudly on failure
if $restored; then
    echo "Kept statusLine wiring in $SETTINGS (points at the restored script)"
elif [ -f "$SETTINGS" ]; then
    if command -v jq >/dev/null 2>&1; then
        tmp=$(mktemp)
        if jq 'del(.statusLine)' "$SETTINGS" > "$tmp" && [ -s "$tmp" ]; then
            mv "$tmp" "$SETTINGS"
            echo "Removed statusLine config from $SETTINGS"
        else
            rm -f "$tmp"
            echo "Warning: could not update $SETTINGS — remove the statusLine key manually" >&2
        fi
    else
        echo "Warning: jq not found — remove the statusLine key from $SETTINGS manually" >&2
    fi
fi

# Remove the per-user usage cache
if [ -d "$CACHE_DIR" ] && [ -O "$CACHE_DIR" ]; then
    rm -rf "$CACHE_DIR"
    echo "Removed cache dir $CACHE_DIR"
fi

# Config dir holds user customizations — only removed on explicit request
if [ "${1:-}" = "--purge" ]; then
    if [ -d "$CONFIG_DIR" ]; then
        rm -rf "$CONFIG_DIR"
        echo "Removed config dir $CONFIG_DIR"
    fi
elif [ -d "$CONFIG_DIR" ]; then
    echo "Kept config dir $CONFIG_DIR (run with --purge to remove it)"
fi

echo ""
echo "Done! Restart Claude Code to apply changes."
