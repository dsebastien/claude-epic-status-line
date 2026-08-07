import React from 'react';
import {interpolate, useCurrentFrame} from 'remotion';
import {Scene} from '../components/Scene';
import {Terminal} from '../components/Terminal';
import {Caption} from '../components/Caption';
import {StatusLine} from '../components/StatusLine';
import {RateLimits} from '../components/RateLimits';
import {DEMO, LIMITS_HOT} from '../data';
import {c} from '../theme';

export const DASHBOARD_DURATION = 390;

const HIGHLIGHT_FROM = 210;

export const Dashboard: React.FC = () => {
  const frame = useCurrentFrame();

  // Bars sweep in one row at a time.
  const rows = LIMITS_HOT.map((r, i) => ({
    ...r,
    reveal: interpolate(frame, [30 + i * 22, 70 + i * 22], [0, 1], {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    }),
    highlight: r.label === 'fable',
  }));

  const highlighting = frame >= HIGHLIGHT_FROM;

  return (
    <Scene durationInFrames={DASHBOARD_DURATION} gap={56}>
      <Terminal title="rate limits">
        <StatusLine {...DEMO.hot} fontSize={21} />
        <div style={{height: 34}} />
        <RateLimits rows={rows} dimNonHighlighted={highlighting} />
      </Terminal>

      <div style={{position: 'relative', width: 1340, height: 190}}>
        {!highlighting ? (
          <div style={{position: 'absolute', inset: 0}}>
            <Caption
              delay={110}
              title="A rate-limit dashboard, right in the status bar"
              body="Your 5-hour window, your 7-day window, and extra-usage credits — each with the exact time it resets."
            />
          </div>
        ) : (
          <div style={{position: 'absolute', inset: 0}}>
            <Caption
              delay={HIGHLIGHT_FROM + 6}
              title="Including per-model weekly limits"
              body="Read from an undocumented field in the usage API. Claude Code's own UI does not show you these numbers anywhere."
              accent={c.green}
            />
          </div>
        )}
      </div>
    </Scene>
  );
};
