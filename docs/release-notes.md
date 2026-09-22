---
title: Release notes
nav_order: 7
---

# Release notes

Full notes and diffs live on the [GitHub releases page](https://github.com/dsebastien/claude-epic-status-line/releases).

## v2.1.0 — what a turn costs

A percentage tells you how much room is left. It does not tell you what the next message costs, and on a 1M-token window those two diverge badly. This release closes that gap, and makes the rate-limit dashboard something you can trim a row at a time.

### What's new

- **Per-turn context cost** — `48k/turn` in the metrics group: the whole context re-sent at the cache-read rate, which is what every message costs before you type a character. Coloured on absolute token thresholds (`CESL_CTX_WARN` 60k, `CESL_CTX_HIGH` 120k), because a percentage of a large window hides exactly this.
- **Turn count** — `88t`, the API requests on this conversation so far (Claude Code ≥ 2.1.251).
- **Pace projection** — the 5-hour and 7-day rows can end with `⇢ 94%`: where the window lands at the current burn rate. Stateless — the window opened at `resets_at` minus its own length, so the elapsed fraction comes from the payload with no state file and no extra request. Quiet unless the pace actually overruns.
- **Context hint line** — one line under the dashboard naming the right command. `/compact` for a window that is nearly full, `/clear` for a session that is merely expensive; a 486k conversation on a 1M window is half full and still pays 48k a turn, so compacting it misses the point.
- **Per-row rate-limit toggles** — `CESL_SHOW_EXTRA`, `CESL_SHOW_SCOPED` and `CESL_SHOW_PROJECTION` switch individual rows. On a Team plan the org can have extra usage enabled at the billing level with nobody intending to use it, and hiding that row no longer means losing the 5-hour, 7-day and per-model rows with it ([#13](https://github.com/dsebastien/claude-epic-status-line/issues/13), reported by [@mh-holdrent](https://github.com/mh-holdrent)).
- **The API call is now skippable** — with both `CESL_SHOW_SCOPED=0` and `CESL_SHOW_EXTRA=0` nothing needs enrichment, so OAuth token resolution and the HTTP request are skipped entirely on every render.
- **`NO_COLOR` support** — `NO_COLOR` and `TERM=dumb` are honoured, and `CESL_COLOR=0`/`1` overrides the detection either way. Stripping happens at a single point before output, so no segment can leak colour past the gate.
- **`explain` reports the new values** — per-turn cost, context thresholds, projections, colour resolution and whether the API fetch was needed at all.

### Compatibility

No breaking changes. Every new segment is on by default and every one has a `CESL_SHOW_*` toggle; existing config files keep working untouched.

```bash
cd claude-epic-status-line && git pull && bash install.sh
```

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
