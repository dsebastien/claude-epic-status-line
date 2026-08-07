---
title: Usage
nav_order: 3
---

# Usage

Once installed there is nothing to run — Claude Code calls the script on every refresh and renders whatever it prints. This page explains what you are looking at.

<video controls playsinline preload="metadata" width="100%" poster="assets/claude-epic-status-line-poster.png">
  <source src="assets/claude-epic-status-line.mp4" type="video/mp4">
  Your browser does not support embedded video. <a href="assets/claude-epic-status-line.mp4">Download the video</a> instead.
</video>

## The display

The output has two parts: one line of session info, and a small dashboard of rate-limit bars underneath.

```
Fable 5 │ 38% (76k/200k) │ …/wks/my-project (feature/epic-v2 S:1 A:2) │ $1.87 · 1h31m · +156/-23 · ● high

5-hour  ██░░░░░░░░  38%  ⟳ 10:00pm
7-day   ███░░░░░░░  29%  ⟳ aug 9
fable   ████░░░░░░  41%  ⟳ aug 6
extra   ██░░░░░░░░  $12.40/$50.00  ⟳ sep 1
```

## Line 1: the session at a glance

| Segment | Example | What it tells you |
|---------|---------|-------------------|
| **Model** | `Fable 5` | The model, shortened, and coloured by family — Opus, Sonnet, Haiku and Fable each get their own hue |
| **Context** | `38% (76k/200k)` | Percentage **and** token counts, so you can act on the absolute number as well as the ratio |
| **Auto-compact warning** | `⚠ 85%` | A steady bold `⚠` appears at `CESL_HIGH` (80% by default) — your cue to `/compact` before it happens to you |
| **200k alert** | `⚠200k+` | A separate badge when you cross the 200k token line |
| **Directory** | `…/wks/my-project` | The last two path components, so long paths do not eat the line |
| **Git branch** | `feature/epic-v2` | Current branch |
| **Git status** | `S:2 U:1 A:3` | Staged, unstaged and untracked file counts |
| **Ahead / behind** | `⇡2⇣1` | Commits ahead of and behind upstream |
| **Worktree** | `⎇wt` | You are inside a git worktree, not the main checkout |
| **Session cost** | `$1.87` | What this session has spent, with its own warn / critical thresholds and optional currency conversion |
| **Duration** | `1h31m` | How long the session has been running |
| **Lines changed** | `+156/-23` | Cumulative lines added and removed — a quick honesty check on what the session produced |
| **Effort** | `● high` | The session's effort level (`●` high, `◑` medium, `◔` low) |
| **Badges** | `fast · [code-reviewer]` | Subagent name, fast mode, thinking, vim mode, non-default output style |

## The rate-limit dashboard

Each row is a progress bar with the same colour escalation as everything else, followed by the value and the exact reset time.

| Row | Source | Meaning |
|-----|--------|---------|
| `5-hour` | stdin payload | Your rolling 5-hour usage window |
| `7-day` | stdin payload | Your rolling 7-day usage window |
| *model name* | usage API | The **per-model weekly limit** for the family you are currently using. Claude Code's own UI does not show this number anywhere |
| `extra` | usage API | Extra-usage credits consumed against your cap, in currency rather than percent. Only rendered when extra usage is enabled on your account |

The 5-hour and 7-day bars come straight from the stdin payload, so they cost nothing. The last two rows are enrichment: they require an OAuth token, and if none is found those rows simply do not render while everything else keeps working.

## Colour coding

One escalation scale drives every percentage-based segment — context usage and every rate bar:

| State | Threshold | Knob |
|-------|-----------|------|
| Dim | below 70% | — |
| Yellow | ≥ 70% | `CESL_WARN` |
| Orange | ≥ 80% (context also gains a bold `⚠`) | `CESL_HIGH` |
| Red | ≥ 90% | `CESL_CRIT` |

Session cost is the exception: it runs on its own `CESL_COST_WARN` / `CESL_COST_CRIT` thresholds, expressed in your display currency. The model name is not part of the scale at all — it is coloured by model family so you always know what you are talking to.

## The `explain` subcommand

When something does not look right, pipe a payload through `explain`:

```bash
cat sample.json | ~/.claude/statusline-command.sh explain
```

It dumps the raw stdin JSON, every parsed value, the API and cache state, and your effective configuration after all layers have been merged. This is the fastest way to tell a config problem apart from a data problem.

To capture a real payload, temporarily point your `statusLine` command at `tee /tmp/statusline.json | bash ~/.claude/statusline-command.sh`.
