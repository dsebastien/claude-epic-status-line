/**
 * Palette mirrors statusline.sh's default 256-colour theme so the video
 * reads as the real tool rather than a stylised approximation.
 */
export const c = {
  page: '#0d0d11',
  card: '#1b1b22',
  chrome: '#22222b',
  border: '#2c2c37',

  text: '#d6d6de',
  dim: '#8a8a96',
  faint: '#5a5a66',

  green: '#22c55e',
  yellow: '#e6c229',
  orange: '#f59e0b',
  red: '#f4636a',

  // Model-family hues
  fable: '#e8a33d',
  opus: '#c08bd0',
  sonnet: '#5aa9e6',
  haiku: '#4dd0c1',

  accent: '#f2b45c',
} as const;

export const FONT_MONO = 'JetBrains Mono, ui-monospace, SFMono-Regular, monospace';

/** Same escalation ladder the script uses: 70 warn, 80 high, 90 critical. */
export const escalate = (pct: number): string => {
  if (pct >= 90) return c.red;
  if (pct >= 80) return c.orange;
  if (pct >= 70) return c.yellow;
  return c.green;
};
