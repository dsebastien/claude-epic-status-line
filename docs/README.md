---
title: Overview
nav_order: 1
permalink: /
---

# Claude Epic Status Line

A feature-rich status line for [Claude Code](https://code.claude.com) that replaces the default status bar with one line of session info plus a rate-limit dashboard. The design principle behind all of it: **dim when healthy, coloured when it needs attention**. Zero-config by default, deeply customizable when you want it.

## See it in action

<video controls playsinline preload="metadata" width="100%" poster="assets/claude-epic-status-line-poster.png">
  <source src="assets/claude-epic-status-line.mp4" type="video/mp4">
  Your browser does not support embedded video. <a href="assets/claude-epic-status-line.mp4">Download the video</a> instead.
</video>

![Claude Epic Status Line screenshot](../screenshot.png)

## Key features

- **Answers every question you have mid-session at a glance** — which model you are on, how much context is left, what branch you are on, what the session has cost, how long it has run, and how close you are to a rate limit. No `/cost`, no external dashboard, no guessing.
- **A rate-limit dashboard built into the status bar** — the 5-hour window, the 7-day window, **per-model weekly limits**, and extra-usage credits, each with the exact time it resets. The per-model numbers come from an undocumented field in the usage API that Claude Code's own UI does not display anywhere.
- **One escalation scale everywhere** — yellow at 70%, orange at 80% (context also gains a steady bold `⚠`, your cue to `/compact`), red at 90%. When something lights up, it means something.
- **Rich git context** — branch, staged / unstaged / untracked counts, ahead-behind arrows, and a worktree marker. Invaluable when you run several Claude sessions in parallel.
- **Configurable down to the hue, or not at all** — thresholds, palette, model-family colours, bar width, glyph sets (`unicode` / `nerd` / `ascii`), per-segment toggles, currency conversion, cache TTL. Every knob is optional.
- **Plain bash, Linux and macOS** — bash 3.2+, BSD or GNU userland. Only `jq`, `curl` and `git` are required, and a warm render takes about 60 ms.

## Quick start

```bash
git clone https://github.com/dsebastien/claude-epic-status-line.git
cd claude-epic-status-line
bash install.sh
```

Restart Claude Code and you are done. The installer backs up any existing status line, scaffolds your config file, and wires up `~/.claude/settings.json`.

See the [Installation](install.md) guide for the manual route and upgrades, [Usage](usage.md) for what every segment means, [Configuration](configuration.md) for every setting, [Tips & best practices](tips.md) for theme recipes, and [Troubleshooting](troubleshooting.md) when something does not render.

## About

Created by [Sébastien Dubois](https://dsebastien.net).

If this is useful to you, you can [buy me a coffee](https://www.buymeacoffee.com/dsebastien) ☕. Source and issues live on [GitHub](https://github.com/dsebastien/claude-epic-status-line).

Inspired by [kamranahmedse/claude-statusline](https://github.com/kamranahmedse/claude-statusline).
