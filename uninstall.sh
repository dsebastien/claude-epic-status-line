#!/usr/bin/env bash
set -euo pipefail

DEST="$HOME/.claude/statusline-command.sh"
SETTINGS="$HOME/.claude/settings.json"

# Remove statusline script
if [ -f "$DEST" ]; then
    rm "$DEST"
    echo "Removed $DEST"
fi

# Restore backup if available
if [ -f "${DEST}.bak" ]; then
    mv "${DEST}.bak" "$DEST"
    echo "Restored previous statusline from backup"
fi

# Remove statusLine from settings
if [ -f "$SETTINGS" ] && command -v jq >/dev/null 2>&1; then
    tmp=$(mktemp)
    jq 'del(.statusLine)' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
    echo "Removed statusLine config from $SETTINGS"
fi

echo ""
echo "Done! Restart Claude Code to apply changes."
