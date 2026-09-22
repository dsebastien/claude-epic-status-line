# Promo video

[Remotion](https://remotion.dev) project for the Claude Epic Status Line promo video.
1920×1080, 30 fps, ~91 s.

## Usage

```bash
npm install
npm run dev      # Remotion Studio, live preview
npm run build    # renders out/claude-epic-status-line.mp4
npm run compress # re-encodes it for the docs site, roughly a third of the size
npm run still    # renders out/poster.png
```

`build` output is CRF 18 and around ten megabytes. `compress` re-encodes at
CRF 24 without the silent audio track, which is visually identical on this
kind of flat, mostly static content. Ship the compressed file to
`docs/assets/`.

## Structure

| File | Role |
|------|------|
| `src/Root.tsx` | Composition registration (`Promo`) |
| `src/Promo.tsx` | Scene ordering and total duration |
| `src/data.ts` | The demo status-line states + rate-limit rows, mirroring `screenshot.png` |
| `src/theme.ts` | Palette and the 70/80/90 escalation ladder from `statusline.sh` |
| `src/components/` | `Terminal`, `StatusLine`, `RateLimits`, `HintLine`, `WarnGlyph`, `CodeBlock`, `Caption`, `Scene` |
| `src/scenes/` | `Hook`, `Title`, `Anatomy`, `Escalation`, `Turn`, `Dashboard`, `Config`, `Install` |

Each scene exports its own `*_DURATION` constant; `Promo.tsx` sums them, so
retiming a scene needs one edit in one place.

## Keeping it truthful

`data.ts` and `theme.ts` are the only places demo values and colours live. When
`statusline.sh` changes its thresholds, palette, or segment layout, update those
two files so the video keeps matching the tool.

Two details worth keeping honest:

- **Per-turn cost is `context × 0.1`, truncated**, matching the script's
  `format_tokens` (awk `%d`), not rounded. 486k context is `48k/turn`.
- **The `⚠` is drawn, not typed** (`WarnGlyph`). Emoji fonts hijack U+26A0 into
  a colour glyph, which breaks both the monospace rhythm and the escalation
  palette; an inline SVG renders the same on every machine.

The version string in `scenes/Title.tsx` needs bumping at each release.
