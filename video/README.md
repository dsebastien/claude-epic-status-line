# Promo video

[Remotion](https://remotion.dev) project for the Claude Epic Status Line promo video.
1920×1080, 30 fps, ~72 s.

## Usage

```bash
npm install
npm run dev     # Remotion Studio, live preview
npm run build   # renders out/claude-epic-status-line.mp4
npm run still   # renders out/poster.png
```

## Structure

| File | Role |
|------|------|
| `src/Root.tsx` | Composition registration (`Promo`) |
| `src/Promo.tsx` | Scene ordering and total duration |
| `src/data.ts` | The two demo status-line states + rate-limit rows, mirroring `screenshot.png` |
| `src/theme.ts` | Palette and the 70/80/90 escalation ladder from `statusline.sh` |
| `src/components/` | `Terminal`, `StatusLine`, `RateLimits`, `CodeBlock`, `Caption`, `Scene` |
| `src/scenes/` | `Hook`, `Title`, `Anatomy`, `Escalation`, `Dashboard`, `Config`, `Install` |

Each scene exports its own `*_DURATION` constant; `Promo.tsx` sums them, so
retiming a scene needs one edit in one place.

## Keeping it truthful

`data.ts` and `theme.ts` are the only places demo values and colours live. When
`statusline.sh` changes its thresholds, palette, or segment layout, update those
two files so the video keeps matching the tool.
