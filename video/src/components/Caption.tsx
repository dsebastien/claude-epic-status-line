import React from 'react';
import {interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {c} from '../theme';

/** Headline + supporting line that slides up under the terminal. */
export const Caption: React.FC<{
  title: string;
  body?: string;
  delay?: number;
  align?: 'center' | 'left';
  accent?: string;
}> = ({title, body, delay = 0, align = 'center', accent = c.accent}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const s = spring({frame: frame - delay, fps, config: {damping: 200}});

  return (
    <div
      style={{
        opacity: s,
        transform: `translateY(${interpolate(s, [0, 1], [26, 0])}px)`,
        textAlign: align,
        maxWidth: 1300,
      }}
    >
      <div
        style={{
          fontFamily: 'Inter, system-ui, sans-serif',
          fontSize: 52,
          fontWeight: 700,
          color: accent,
          letterSpacing: -0.5,
        }}
      >
        {title}
      </div>
      {body ? (
        <div
          style={{
            fontFamily: 'Inter, system-ui, sans-serif',
            fontSize: 32,
            fontWeight: 400,
            color: c.dim,
            marginTop: 14,
            lineHeight: 1.45,
          }}
        >
          {body}
        </div>
      ) : null}
    </div>
  );
};
