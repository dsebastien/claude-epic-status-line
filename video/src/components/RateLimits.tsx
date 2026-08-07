import React from 'react';
import {c, escalate, FONT_MONO} from '../theme';

export type LimitRow = {
  label: string;
  pct: number;
  /** Text shown right of the bar. Defaults to `${pct}%`. */
  value?: string;
  reset: string;
  /** Fraction of the bar to draw, 0..1. Lets rows animate in one by one. */
  reveal?: number;
  highlight?: boolean;
};

const BAR_W = 210;
const BAR_H = 26;

export const RateLimits: React.FC<{
  rows: LimitRow[];
  fontSize?: number;
  dimNonHighlighted?: boolean;
}> = ({rows, fontSize = 28, dimNonHighlighted = false}) => {
  const anyHighlight = rows.some((r) => r.highlight);

  return (
    <div
      style={{
        fontFamily: FONT_MONO,
        fontSize,
        display: 'flex',
        flexDirection: 'column',
        gap: 14,
      }}
    >
      {rows.map((r) => {
        const color = escalate(r.pct);
        const reveal = r.reveal ?? 1;
        const dim =
          dimNonHighlighted && anyHighlight && !r.highlight ? 0.25 : 1;

        return (
          <div
            key={r.label}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 24,
              opacity: dim,
            }}
          >
            <span style={{color: c.text, width: 130}}>{r.label}</span>

            <div
              style={{
                width: BAR_W,
                height: BAR_H,
                background: 'rgba(255,255,255,0.05)',
                border: `1px solid ${c.border}`,
                borderRadius: 3,
                overflow: 'hidden',
              }}
            >
              <div
                style={{
                  width: `${Math.min(100, r.pct) * reveal}%`,
                  height: '100%',
                  background: color,
                }}
              />
            </div>

            <span style={{color, minWidth: 90}}>{r.value ?? `${r.pct}%`}</span>
            <span style={{color: c.faint}}>↺ {r.reset}</span>
          </div>
        );
      })}
    </div>
  );
};
