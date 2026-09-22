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
Fable 5 │ 38% (76k/200k) │ …/wks/my-project (feature/epic-v2 S:1 A:2) │ $1.87 · 1h31m · +156/-23 · 7.6k/turn · 88t · ● high

5-hour  ██░░░░░░░░  38%  ⟳ 10:00pm  ⇢ 94%
7-day   ███░░░░░░░  29%  ⟳ aug 9
fable   ████░░░░░░  41%  ⟳ aug 6
extra   ██░░░░░░░░  $12.40/$50.00  ⟳ sep 1
```

A third part appears only when it has something to say: a hint line under the dashboard when the session has grown expensive.

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
| **Per-turn cost** | `7.6k/turn` | What the next message costs *before you type a character* — the whole context re-sent at the cache-read rate. Yellow past `CESL_CTX_WARN`, red past `CESL_CTX_HIGH` |
| **Turns** | `88t` | API requests on this conversation so far. Requires Claude Code ≥ 2.1.251 |
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

Each row can be hidden on its own — see [trimming the rate-limit dashboard](configuration.md#trimming-the-rate-limit-dashboard). Turning off both API-backed rows also skips the API call entirely.

### The pace projection

The 5-hour and 7-day rows can end with `⇢ 94%`: where the window lands at this rate, extrapolated from how far into it you already are.

```
5-hour  ███░░░░░░░  38%  ⟳ 2:42pm  ⇢ 94%
```

38% burned two hours into a five-hour window is not 38% of a problem — it is a window that runs out before it resets. The projection needs no state and no extra API call: the window opened at `resets_at` minus its own length, so the elapsed fraction follows from the reset stamp alone.

It stays quiet unless the pace actually overruns. Nothing renders in the first tenth of a window (too little signal to extrapolate from), when the projection lands below `CESL_WARN`, or when it barely moves off the current figure. Hide it with `CESL_SHOW_PROJECTION=0`.

### The context hint

Past a threshold, a line appears under the dashboard saying what to do about it:

```
⚠ 93% of the window used — /compact now, or /clear if you have switched task
⚠ 486k context — every turn re-sends it at 48k before you type — /clear between tasks
```

The two are different problems and take different commands. A nearly full **window** needs `/compact`; there is no room left. A merely **large** session needs `/clear`; a 486k conversation on a 1M window is only half full and still pays 48k on every turn, so compacting it is beside the point — starting a fresh session for the next task is the fix.

The first fires at `CESL_HIGH` (80% of the window), the second at `CESL_CTX_HIGH` (120k tokens). `CESL_SHOW_HINT=0` turns both off.

## Colour coding

One escalation scale drives every percentage-based segment — context usage and every rate bar:

| State | Threshold | Knob |
|-------|-----------|------|
| Dim | below 70% | — |
| Yellow | ≥ 70% | `CESL_WARN` |
| Orange | ≥ 80% (context also gains a bold `⚠`) | `CESL_HIGH` |
| Red | ≥ 90% | `CESL_CRIT` |

Session cost is the exception: it runs on its own `CESL_COST_WARN` / `CESL_COST_CRIT` thresholds, expressed in your display currency. The per-turn cost is the other exception: it runs on absolute token counts (`CESL_CTX_WARN` / `CESL_CTX_HIGH`), because a percentage of a 1M window says nothing about what a message costs. The model name is not part of the scale at all — it is coloured by model family so you always know what you are talking to.

### Turning colour off

`NO_COLOR` and `TERM=dumb` are both honoured, and `CESL_COLOR` overrides the detection in either direction:

```bash
NO_COLOR=1                   # plain text
CESL_COLOR=0                 # same, regardless of the environment
CESL_COLOR=1                 # colour even when NO_COLOR is set
```

## The `explain` subcommand

When something does not look right, pipe a payload through `explain`:

```bash
cat sample.json | ~/.claude/statusline-command.sh explain
```

It dumps the raw stdin JSON, every parsed value, the API and cache state, and your effective configuration after all layers have been merged. This is the fastest way to tell a config problem apart from a data problem.

To capture a real payload, temporarily point your `statusLine` command at `tee /tmp/statusline.json | bash ~/.claude/statusline-command.sh`.
