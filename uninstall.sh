#!/usr/bin/env bash
# Usage: ./uninstall.sh [--purge]
#   --purge  also delete ~/.config/claude-epic-status-line (your customizations)
set -euo pipefail

DEST="$HOME/.claude/statusline-command.sh"
SETTINGS="$HOME/.claude/settings.json"
CONFIG_DIR="$HOME/.config/claude-epic-status-line"
CACHE_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/claude-statusline-$(id -u)"
STATUSLINE_BAK="$HOME/.claude/statusline-settings.bak.json"

# Never touch a statusline that isn't ours (another tool may have replaced it
# after our install) — in that case leave the script and settings alone
foreign=false
if [ -f "$DEST" ] && ! grep -q "Claude Epic Status Line" "$DEST" 2>/dev/null; then
    foreign=true
    echo "Note: $DEST is not this tool's script — leaving it and $SETTINGS untouched"
fi

restored=false
if ! $foreign; then
    # Remove statusline script
    if [ -f "$DEST" ]; then
        rm "$DEST"
        echo "Removed $DEST"
    fi

    # Restore backup if available
    if [ -f "${DEST}.bak" ]; then
        mv "${DEST}.bak" "$DEST"
        restored=true
        echo "Restored previous statusline from backup"
    fi

    # Settings: restore a saved foreign statusLine value if install preserved
    # one; else keep the wiring when a previous script was restored (same
    # path); otherwise remove the statusLine key — loudly on failure.
    # cp (not mv) keeps a symlinked settings.json pointing at its target.
    if [ -f "$STATUSLINE_BAK" ] && [ -f "$SETTINGS" ] && command -v jq >/dev/null 2>&1; then
        tmp=$(mktemp)
        if jq --slurpfile p "$STATUSLINE_BAK" '.statusLine = $p[0]' "$SETTINGS" > "$tmp" && [ -s "$tmp" ]; then
            cp "$tmp" "$SETTINGS" && rm -f "$tmp"
            rm -f "$STATUSLINE_BAK"
            echo "Restored previous statusLine setting in $SETTINGS"
        else
            rm -f "$tmp"
            echo "Warning: could not restore $STATUSLINE_BAK into $SETTINGS — merge it manually" >&2
        fi
    elif $restored; then
        echo "Kept statusLine wiring in $SETTINGS (points at the restored script)"
    elif [ -f "$SETTINGS" ]; then
        if command -v jq >/dev/null 2>&1; then
            # Only delete the statusLine key if it still points at OUR script —
            # a foreign wiring installed after us is not ours to remove
            if ! jq empty "$SETTINGS" >/dev/null 2>&1; then
                echo "Warning: $SETTINGS is not valid JSON — remove the statusLine key manually" >&2
                cur="__invalid__"
            else
                cur=$(jq -r '.statusLine.command // ""' "$SETTINGS" 2>/dev/null || true)
            fi
            case "$cur" in
                "__invalid__")
                    ;; # already warned
                "")
                    ;; # no statusLine key — nothing to do
                *"$DEST"*)
                    tmp=$(mktemp)
                    if jq 'del(.statusLine)' "$SETTINGS" > "$tmp" && [ -s "$tmp" ]; then
                        cp "$tmp" "$SETTINGS" && rm -f "$tmp"
                        echo "Removed statusLine config from $SETTINGS"
                    else
                        rm -f "$tmp"
                        echo "Warning: could not update $SETTINGS — remove the statusLine key manually" >&2
                    fi
                    ;;
                *)
                    echo "Kept statusLine in $SETTINGS (it no longer points at this tool)"
                    ;;
            esac
        else
            echo "Warning: jq not found — remove the statusLine key from $SETTINGS manually" >&2
        fi
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
