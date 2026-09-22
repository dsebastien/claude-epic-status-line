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

### Offline mode — no API call at all

The per-model and extra-usage rows are the only two that need the usage API. Drop both and the status line never resolves a token or opens a connection, while the 5-hour and 7-day bars keep working from the stdin payload.

```bash
CESL_SHOW_SCOPED=0
CESL_SHOW_EXTRA=0
```

Drop just one if that is all you want — `CESL_SHOW_EXTRA=0` is the common case on a Team plan, where the org can have extra usage enabled at the billing level even though nobody intends to spend credits.

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

## Watch `k/turn`, not the percentage

The percentage answers "how much room is left". `48k/turn` answers "what does the next message cost", and on a large window they disagree: 486k of a 1M window is under half full and still re-sends 48k tokens on every turn, because the API is stateless and turn N re-sends turns 1..N-1. A one-word reply costs exactly what a complex request costs.

The practical consequence is that **`/clear` between unrelated tasks is the biggest lever you have**, and it is free. Four forty-turn sessions move less than half the context of one hundred-and-sixty-turn session, for identical work — and none of them goes near the ceiling. Shorter prompts are not the lever; session size is.

Tune `CESL_CTX_HIGH` to the number at which you want to be told:

```bash
CESL_CTX_WARN=40000
CESL_CTX_HIGH=80000
```

## Treat `⇢` as the number that matters on the rate rows

`5-hour ███░░░░░░░ 38% ⟳ 2:42pm ⇢ 94%` is not a 38% problem. The projection extrapolates your current burn rate to the end of the window, and it only appears when that pace overruns — so when you see it, the window runs out before it resets. Either slow down, switch model families, or plan the rest of the work around the reset time next to it.

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
