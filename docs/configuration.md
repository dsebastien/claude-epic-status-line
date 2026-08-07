---
title: Configuration
nav_order: 4
---

# Configuration

Everything is optional. With zero configuration the status line renders its default design.

## How settings layer

Settings are resolved in this order, with later layers winning:

1. **Script defaults** — baked into `statusline.sh`
2. **`~/.config/claude-epic-status-line/config.sh`** — a plain shell file, sourced
3. **`CESL_*` environment variables** — highest priority

`install.sh` scaffolds the config file with every knob present but commented out at its default value, so opening it is the fastest way to see what is tunable.

Point the script at a different config file with `CESL_CONFIG=/path/to/config.sh`.

A typo in a numeric knob cannot break rendering: non-numeric and out-of-range values fall back to the default rather than producing a broken line.

## Escalation thresholds

| Variable | Default | Description |
|----------|---------|-------------|
| `CESL_WARN` | `70` | Percentage at which context and rate bars turn yellow |
| `CESL_HIGH` | `80` | Turn orange; context also gains a steady bold `⚠` |
| `CESL_CRIT` | `90` | Turn red |

## Session cost

| Variable | Default | Description |
|----------|---------|-------------|
| `CESL_COST_WARN` | `5` | Session cost (in display currency) at which the number turns yellow |
| `CESL_COST_CRIT` | `20` | Cost at which it turns red |
| `CESL_CURRENCY_SYMBOL` | `$` | Symbol prefixed to costs |
| `CESL_CURRENCY_RATE` | `1` | Multiplier applied to the USD figure Claude Code reports |

To display costs in euros at roughly 0.92 to the dollar:

```bash
CESL_CURRENCY_SYMBOL='€'
CESL_CURRENCY_RATE=0.92
```

## Bars, glyphs and caching

| Variable | Default | Description |
|----------|---------|-------------|
| `CESL_BAR_WIDTH` | `10` | Rate-limit bar width in characters (clamped to 1–200) |
| `CESL_GLYPHS` | `unicode` | Glyph set: `unicode`, `nerd` (requires a Nerd Font), or `ascii` for maximum compatibility |
| `CESL_CACHE_TTL` | `60` | Seconds to cache the usage API response |
| `CESL_CONFIG` | `~/.config/claude-epic-status-line/config.sh` | Path to the config file itself |

### Glyph sets

| | `unicode` | `nerd` | `ascii` |
|---|---|---|---|
| Separator | `│` | `│` | `\|` |
| Bar fill / empty | `█` `░` | `█` `░` | `#` `.` |
| Warning | `⚠` | `⚠` | `!` |
| Reset marker | `⟳` | `⟳` | `~` |
| Ahead / behind | `⇡` `⇣` | `⇡` `⇣` | `^` `v` |
| Worktree | `⎇wt` | `⎇wt` | `wt` |
| Effort | `●` `◑` `◔` | `●` `◑` `◔` | `*` `o` `.` |

`nerd` additionally uses a branch glyph from the Nerd Font private-use range. Pick `ascii` when your terminal or font mangles box-drawing characters.

## Segment toggles

Set any of these to `0` to hide that segment. All default to `1`.

| Variable | Hides |
|----------|-------|
| `CESL_SHOW_MODEL` | The model name |
| `CESL_SHOW_CONTEXT` | Context percentage and token counts |
| `CESL_SHOW_DIR` | The working directory |
| `CESL_SHOW_GIT` | Branch, status counts, ahead/behind, worktree marker |
| `CESL_SHOW_COST` | Session cost |
| `CESL_SHOW_DURATION` | Session duration |
| `CESL_SHOW_LINES` | Lines added/removed |
| `CESL_SHOW_EFFORT` | Effort level |
| `CESL_SHOW_BADGES` | Subagent, fast mode, thinking, vim, output style |
| `CESL_SHOW_RATE_BLOCK` | The whole rate-limit dashboard |

## Palette

Colours are truecolor `"R;G;B"` strings.

| Variable | Default | Applies to |
|----------|---------|------------|
| `CESL_COLOR_TEXT` | `220;220;220` | Default text |
| `CESL_COLOR_OK` | `0;175;80` | Healthy state |
| `CESL_COLOR_WARN` | `230;200;0` | Warn state (≥ `CESL_WARN`) |
| `CESL_COLOR_HIGH` | `255;176;85` | High state (≥ `CESL_HIGH`) |
| `CESL_COLOR_CRIT` | `255;85;85` | Critical state (≥ `CESL_CRIT`) |
| `CESL_COLOR_DIR` | `86;182;194` | Working directory |
| `CESL_COLOR_AGENT` | `180;140;255` | Subagent badge |

### Model-family hues

These colour the model name only.

| Variable | Default |
|----------|---------|
| `CESL_COLOR_OPUS` | `180;140;255` |
| `CESL_COLOR_SONNET` | `0;153;255` |
| `CESL_COLOR_HAIKU` | `64;200;180` |
| `CESL_COLOR_FABLE` | `240;190;60` |
| `CESL_COLOR_MODEL` | `0;153;255` (fallback for unrecognised models) |

## Authentication and caching

The per-model weekly limits and extra-usage credits come from the Anthropic usage API. The OAuth token is resolved in this order:

1. `CLAUDE_CODE_OAUTH_TOKEN`
2. `~/.claude/.credentials.json`
3. `secret-tool` (Linux keyring)
4. macOS Keychain (`security find-generic-password`)

Responses are cached in a private per-user directory under `$XDG_RUNTIME_DIR` (falling back to `$TMPDIR`, then `/tmp`), created with mode `700` and validated for ownership before use. Concurrent Claude sessions share a single fetch through a lock rather than each hitting the API.

If no token is found, those two rows do not render and nothing else is affected.
