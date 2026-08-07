---
title: Installation
nav_order: 2
---

# Installation

## Requirements

| Tool | Why |
|------|-----|
| `jq` | Parses the JSON payload Claude Code sends on stdin |
| `curl` | Fetches rate-limit enrichment from the Anthropic usage API |
| `git` | Branch, status and worktree detection |

Plus bash 3.2 or newer. Linux and macOS are both supported, with either BSD or GNU userland — date formatting and credential resolution adapt to the platform automatically.

Claude Code **2.1.140 or newer** is recommended: from that version the stdin payload carries your 5-hour and 7-day rate-limit data, so those bars render without touching the API at all.

## Quick install

```bash
git clone https://github.com/dsebastien/claude-epic-status-line.git
cd claude-epic-status-line
bash install.sh
```

The installer:

1. Backs up any existing status line command and your `~/.claude/settings.json`.
2. Copies `statusline.sh` to `~/.claude/statusline-command.sh`.
3. Scaffolds `~/.config/claude-epic-status-line/config.sh` with every knob present but commented out at its default value.
4. Writes the `statusLine` key into `~/.claude/settings.json`.

Restart Claude Code to pick it up.

## Manual install

1. Copy `statusline.sh` to `~/.claude/statusline-command.sh`.
2. Add this to your `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash '/home/YOUR_USER/.claude/statusline-command.sh'"
  }
}
```

3. Restart Claude Code.

Nothing else is required — the config file is optional and the script falls back to its defaults when it is absent.

## Upgrading

```bash
cd claude-epic-status-line
git pull
bash install.sh
```

Re-running the installer never touches `~/.config/claude-epic-status-line/config.sh`. Your settings survive upgrades.

## Uninstalling

```bash
bash uninstall.sh
```

This restores your previous status line and settings from the backup taken at install time. Your config directory is left in place unless you pass `--purge`.

To do it by hand: remove the `statusLine` key from `~/.claude/settings.json` and delete `~/.claude/statusline-command.sh`.
