---
title: Troubleshooting
nav_order: 6
---

# Troubleshooting

Start with [`explain`](usage.md#the-explain-subcommand) — it prints the raw stdin payload, every parsed value, the API and cache state, and your effective configuration. Most problems are visible in that output.

## Nothing renders at all

- Confirm the `statusLine` key exists in `~/.claude/settings.json` and points at a file that exists.
- Restart Claude Code. Status line configuration is read at startup.
- Run the script by hand: `echo '{}' | bash ~/.claude/statusline-command.sh`. If bash reports a syntax error, the copy is truncated — reinstall.
- Check that `jq` is on the `PATH` **that Claude Code sees**, which is not always your interactive shell's `PATH`.

## The rate-limit dashboard is missing

The 5-hour and 7-day bars come from the stdin payload, which requires Claude Code **2.1.140 or newer**. Upgrade Claude Code, then run `explain` and look at the raw JSON: if there is no rate-limit data in the payload, the version is the cause.

Also confirm `CESL_SHOW_RATE_BLOCK` is not set to `0`.

## The per-model and extra-usage rows never appear

Those two rows are API enrichment and need an OAuth token. `explain` reports whether one was resolved. The lookup order is:

1. `CLAUDE_CODE_OAUTH_TOKEN`
2. `~/.claude/.credentials.json`
3. `secret-tool` (Linux keyring)
4. macOS Keychain

If none resolves, the rows are skipped deliberately — this is not an error state, and the rest of the line is unaffected.

Extra-usage credits only render when extra usage is actually enabled on your account.

## Values look stale

The usage API response is cached for `CESL_CACHE_TTL` seconds (60 by default). Lower it, or delete the cache directory reported by `explain`, to force a refresh.

Cost, duration and lines-changed come from the stdin payload and are never cached.

## Boxes, question marks or mangled characters

Your terminal or font cannot render the default glyph set. Switch:

```bash
CESL_GLYPHS=ascii
```

Use `nerd` only if you actually have a Nerd Font installed — it draws a branch glyph from the private-use range that other fonts render as a box.

## The line is cut off on the right

Claude Code truncates rather than wraps. Turn off segments you do not need or shrink the bars — see [Keep the line short on narrow terminals](tips.md#keep-the-line-short-on-narrow-terminals).

## Colours look wrong or absent

The palette uses truecolor escape sequences. In a terminal limited to 256 colours the output degrades, sometimes badly. Confirm your terminal advertises truecolor (`echo $COLORTERM` should print `truecolor` or `24bit`), and remember that multiplexers like `tmux` need explicit truecolor passthrough configured.

## A config change has no effect

Environment variables win over the config file. If `CESL_*` is exported in your shell profile, it overrides whatever you edit in `config.sh`. `explain` shows the merged result, which settles this quickly.

Also check `CESL_CONFIG` — if it is set, the script reads that path instead of the default one.

## The status line feels slow

A warm render is around 60 ms. If it feels slower:

- The first render after the cache expires includes an API round trip. Raise `CESL_CACHE_TTL`.
- Git operations in a very large repository can dominate. Git and keychain lookups are bounded to roughly 2 seconds so they can never freeze the line, but you can remove the cost entirely with `CESL_SHOW_GIT=0`.

## Something else

Open an issue on [GitHub](https://github.com/dsebastien/claude-epic-status-line/issues), including the `explain` output with any token redacted.
