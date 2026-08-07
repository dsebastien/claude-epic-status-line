---
title: Tips & best practices
nav_order: 5
---

# Tips & best practices

## Theme recipes

Copy any of these into `~/.config/claude-epic-status-line/config.sh`.

### Monochrome minimal — no hues, just states

Model families stop competing for attention; only the escalation colours remain meaningful.

```bash
CESL_COLOR_DIR='150;150;150'
CESL_COLOR_OPUS='200;200;200'
CESL_COLOR_SONNET='200;200;200'
CESL_COLOR_HAIKU='200;200;200'
CESL_COLOR_FABLE='200;200;200'
CESL_COLOR_MODEL='200;200;200'
```

### Wide dashboard — chunkier bars, ASCII-safe

```bash
CESL_BAR_WIDTH=20
CESL_GLYPHS=ascii
```

### Quiet mode — just model, context and rate limits

```bash
CESL_SHOW_DIR=0
CESL_SHOW_COST=0
CESL_SHOW_DURATION=0
CESL_SHOW_LINES=0
CESL_SHOW_EFFORT=0
CESL_SHOW_BADGES=0
CESL_SHOW_GIT=0
```

### Costs in euros

```bash
CESL_CURRENCY_SYMBOL='€'
CESL_CURRENCY_RATE=0.92
```

## Tune the thresholds to how you actually work

The defaults (70 / 80 / 90) suit long sessions where auto-compact is an annoyance rather than a disaster. If you routinely paste large files, move the warning earlier so you have time to react:

```bash
CESL_WARN=55
CESL_HIGH=70
CESL_CRIT=85
```

The cost thresholds work the same way, and they are the ones worth personalising most: `CESL_COST_WARN` should sit at the number that makes you glance at the clock, and `CESL_COST_CRIT` at the number that makes you stop.

## Use the orange `⚠` as a workflow signal

The bold `⚠` at `CESL_HIGH` exists so you can `/compact` on your own terms — at a natural break, with a summary you control — rather than having auto-compact fire mid-task. Treat it as "finish the current thought, then compact".

## Watch the per-model row before starting big work

The per-model weekly bar is the one that ruins weeks. Glance at it before kicking off a long Opus session on a Monday: if it is already orange, either switch families or plan the work around the reset time shown at the end of the row.

## Running several sessions in parallel

The git segment earns its place here. The `⎇wt` marker and the branch name make it obvious which worktree a terminal belongs to, and the staged/unstaged/untracked counts tell you at a glance which session has uncommitted work waiting.

All sessions share one usage-API cache and a single-flight lock, so running five of them does not mean five times the API calls.

## Keep the line short on narrow terminals

Claude Code does not wrap the status line — a long line is simply cut off. On a narrow terminal, turn off what you can reconstruct from elsewhere:

```bash
CESL_SHOW_LINES=0
CESL_SHOW_DIR=0
CESL_BAR_WIDTH=6
```

## Reach for `explain` before editing config

`explain` prints the effective configuration after all three layers have merged, which usually turns "why is this not applying?" into a one-look answer. See [Usage](usage.md#the-explain-subcommand).
