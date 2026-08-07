import React from 'react';
import {interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {Scene} from '../components/Scene';
import {StatusLine} from '../components/StatusLine';
import {Terminal} from '../components/Terminal';
import {c, FONT_MONO} from '../theme';
import {DEMO} from '../data';

export const TITLE_DURATION = 150;

export const Title: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const s = spring({frame: frame - 8, fps, config: {damping: 200}});

  return (
    <Scene durationInFrames={TITLE_DURATION} gap={54}>
      <div
        style={{
          opacity: s,
          transform: `translateY(${interpolate(s, [0, 1], [30, 0])}px)`,
          textAlign: 'center',
        }}
      >
        <div
          style={{
            fontFamily: 'Inter, system-ui, sans-serif',
            fontSize: 88,
            fontWeight: 800,
            color: c.text,
            letterSpacing: -2,
          }}
        >
          Claude Epic Status Line
        </div>
        <div
          style={{
            fontFamily: FONT_MONO,
            fontSize: 30,
            color: c.accent,
            marginTop: 18,
          }}
        >
          v2.0.0 — a status bar that answers your questions
        </div>
      </div>

      <div
        style={{
          opacity: interpolate(frame, [40, 65], [0, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
          }),
        }}
      >
        <Terminal title="cruising">
          <StatusLine {...DEMO.cruising} />
        </Terminal>
      </div>
    </Scene>
  );
};
