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

# Validate settings.json BEFORE touching anything — install must never
# replace the active statusline script and then fail on the settings step
if [ -f "$SETTINGS" ] && [ -s "$SETTINGS" ] \
   && ! jq -es 'length == 1 and (.[0] | type == "object")' "$SETTINGS" >/dev/null 2>&1; then
    echo "Error: $SETTINGS is not a single JSON object — fix it first, then re-run install.sh" >&2
    exit 1
fi

mkdir -p "$HOME/.claude"

# Backup an existing statusline script — but never overwrite an earlier
# backup, and never back up our own script over the user's original
# (re-running install.sh is the normal upgrade path)
if [ -f "$DEST" ] && [ ! -f "${DEST}.bak" ] \
   && ! grep -q "Claude Epic Status Line" "$DEST" 2>/dev/null; then
    cp "$DEST" "${DEST}.bak"
    echo "Backed up existing statusline to ${DEST}.bak"
fi

# Copy script — break a symlinked destination first so we never overwrite a
# foreign symlink target through it
[ -L "$DEST" ] && rm -f "$DEST"
cp "$SCRIPT_DIR/statusline.sh" "$DEST"
chmod +x "$DEST"
echo "Installed statusline script to $DEST"

# Scaffold config file (never overwrites an existing one)
CONFIG_DIR="$HOME/.config/claude-epic-status-line"
CONFIG_FILE="$CONFIG_DIR/config.sh"
if [ -f "$CONFIG_FILE" ]; then
    echo "Existing config preserved at $CONFIG_FILE"
else
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" <<'CFGEOF'
# Claude Epic Status Line — configuration
#
# Every knob below is optional and shown at its default value, commented out.
# Uncomment and edit to override. Layering: script defaults < this file <
# CESL_* environment variables (environment wins).
#
# Colors are truecolor "R;G;B" triples.

## Escalation thresholds (one scale for context % and rate-limit %)
#CESL_WARN=70
#CESL_HIGH=80
#CESL_CRIT=90

## Session cost thresholds (in display currency)
#CESL_COST_WARN=5
#CESL_COST_CRIT=20

## Rate-limit bars
#CESL_BAR_WIDTH=10

## Usage API cache TTL in seconds (raise if you run many concurrent sessions)
#CESL_CACHE_TTL=60

## Currency (display conversion only; costs come from Claude Code in USD)
#CESL_CURRENCY_SYMBOL='$'
#CESL_CURRENCY_RATE=1

## Glyph set: unicode (default) | nerd | ascii
#CESL_GLYPHS=unicode

## Segment toggles (1 = shown, 0 = hidden)
#CESL_SHOW_MODEL=1
#CESL_SHOW_CONTEXT=1
#CESL_SHOW_DIR=1
#CESL_SHOW_GIT=1
#CESL_SHOW_COST=1
#CESL_SHOW_DURATION=1
#CESL_SHOW_LINES=1
#CESL_SHOW_EFFORT=1
#CESL_SHOW_BADGES=1
#CESL_SHOW_RATE_BLOCK=1

## Palette
#CESL_COLOR_TEXT='220;220;220'
#CESL_COLOR_OK='0;175;80'
#CESL_COLOR_WARN='230;200;0'
#CESL_COLOR_HIGH='255;176;85'
#CESL_COLOR_CRIT='255;85;85'
#CESL_COLOR_DIR='86;182;194'
#CESL_COLOR_AGENT='180;140;255'

## Model-family hues (colors the model name only)
#CESL_COLOR_OPUS='180;140;255'
#CESL_COLOR_SONNET='0;153;255'
#CESL_COLOR_HAIKU='64;200;180'
#CESL_COLOR_FABLE='240;190;60'
#CESL_COLOR_MODEL='0;153;255'
CFGEOF
    echo "Scaffolded config at $CONFIG_FILE (all knobs commented out at defaults)"
fi

# Update settings.json (jq @sh shell-quotes the path robustly — spaces,
# quotes, and backticks in $HOME all survive)
STATUSLINE_BAK="$HOME/.claude/statusline-settings.bak.json"
if [ -f "$SETTINGS" ] && [ -s "$SETTINGS" ]; then
    # Preserve a pre-existing foreign statusLine value so uninstall can restore it
    prev=$(jq -c '.statusLine // empty' "$SETTINGS" 2>/dev/null || true)
    if [ -n "$prev" ] && [ ! -f "$STATUSLINE_BAK" ] \
       && ! printf '%s' "$prev" | grep -qF "$DEST"; then
        printf '%s\n' "$prev" > "$STATUSLINE_BAK"
        echo "Saved previous statusLine setting to $STATUSLINE_BAK"
    fi
    # Merge statusLine into existing settings; fail loudly on invalid JSON
    tmp=$(mktemp)
    if jq --arg dest "$DEST" \
        '. + {statusLine: {type: "command", command: ("bash " + ($dest | @sh))}}' \
        "$SETTINGS" > "$tmp" && [ -s "$tmp" ]; then
        # cp (not mv) so a symlinked settings.json keeps pointing at its target
        cp "$tmp" "$SETTINGS" && rm -f "$tmp"
        echo "Updated $SETTINGS with statusLine config"
    else
        rm -f "$tmp"
        echo "Error: could not update $SETTINGS (invalid JSON?)." >&2
        echo "Fix the file, then re-run install.sh." >&2
        exit 1
    fi
else
    # Create new settings file
    if jq -n --arg dest "$DEST" \
        '{statusLine: {type: "command", command: ("bash " + ($dest | @sh))}}' > "$SETTINGS"; then
        echo "Created $SETTINGS with statusLine config"
    else
        echo "Error: could not create $SETTINGS" >&2
        exit 1
    fi
fi

echo ""
echo "Done! Restart Claude Code to see the new status line."
