---
title: Release notes
nav_order: 7
---

# Release notes

Full notes and diffs live on the [GitHub releases page](https://github.com/dsebastien/claude-epic-status-line/releases).

## v2.0.0 — the epic redesign

A ground-up rewrite, designed around one idea: **quiet when healthy, loud exactly where something needs attention.**

### What's new

- **New layout** — a refined single line (model · context · dir+git · cost · duration · lines ± · effort · badges) plus an always-visible rate-limit dashboard with `█░` bars for the 5-hour window, 7-day window, **per-model weekly limits** (data the official UI does not surface), and extra-usage credits.
- **Semantic colour** — one escalation scale everywhere (yellow ≥ 70%, orange ≥ 80%, red ≥ 90%), model name coloured by family, and a steady bold `⚠` instead of a blinking one.
- **stdin-first data** — rate limits, cost, duration, lines changed, effort, fast-mode / thinking / vim / output-style badges and the subagent name all come from Claude Code's own status JSON (2.1.140 or newer recommended; older versions degrade gracefully). The usage API is queried only for enrichment, cached per-user with a single-flight lock and negative caching.
- **Configuration system** — zero-config by default; `~/.config/claude-epic-status-line/config.sh` (scaffolded by `install.sh` with all knobs commented out) plus `CESL_*` environment overrides for thresholds, palette and model hues, bar width, glyph sets, per-segment toggles, currency conversion and cache TTL.
- **`explain` subcommand** — pipe a status JSON through `statusline.sh explain` to see the raw input, every parsed value, cache state and effective config.
- **Adversarially reviewed** — four review rounds across two reviewers, 34 findings fixed: terminal-escape injection, OAuth token exposure on argv, arithmetic overflow and octal traps, hostile-JSON handling, installer data-loss paths, cache races and macOS portability bugs. Hostile inputs now degrade, never corrupt.

### Breaking changes

- Rate-limit labels renamed `current` / `weekly` → `5-hour` / `7-day`; bars are now `█░` (dots are still available via `CESL_GLYPHS`).
- Effort is read from the session's stdin (`effort.level`); the `~/.claude/settings.json` effort read is gone.
- The usage cache moved to a per-user directory (`$XDG_RUNTIME_DIR/claude-statusline-$UID` or equivalent).
- The blinking context warning was replaced by a steady bold one.

### Upgrading

```bash
cd claude-epic-status-line && git pull && bash install.sh
```

Your config file is never touched by the installer.

## v1.0.1 — bug-fix release

- Fixed rate-limit percentages exceeding 100%.
- Revived the cost and duration segments, which could silently render empty.
- Hardened the usage cache.
- Fixed date handling on macOS.

## v1.0.0

Initial release: model, context usage, git branch and status, session cost, duration and rate limits in a single status line.
