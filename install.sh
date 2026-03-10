#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.claude/statusline-command.sh"
SETTINGS="$HOME/.claude/settings.json"

# Check dependencies
for cmd in jq curl git; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: '$cmd' is required but not installed."
        exit 1
    fi
done

# Backup existing statusline script if present
if [ -f "$DEST" ]; then
    cp "$DEST" "${DEST}.bak"
    echo "Backed up existing statusline to ${DEST}.bak"
fi

# Copy script
cp "$SCRIPT_DIR/statusline.sh" "$DEST"
chmod +x "$DEST"
echo "Installed statusline script to $DEST"

# Update settings.json
mkdir -p "$HOME/.claude"

if [ -f "$SETTINGS" ]; then
    # Merge statusLine into existing settings
    tmp=$(mktemp)
    jq '. + {"statusLine": {"type": "command", "command": "bash '"$DEST"'"}}' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
    echo "Updated $SETTINGS with statusLine config"
else
    # Create new settings file
    cat > "$SETTINGS" <<EOF
{
  "statusLine": {
    "type": "command",
    "command": "bash $DEST"
  }
}
EOF
    echo "Created $SETTINGS with statusLine config"
fi

echo ""
echo "Done! Restart Claude Code to see the new status line."
