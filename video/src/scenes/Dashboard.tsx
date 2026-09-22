import React from 'react';
import {interpolate, useCurrentFrame} from 'remotion';
import {Scene} from '../components/Scene';
import {Terminal} from '../components/Terminal';
import {Caption} from '../components/Caption';
import {StatusLine} from '../components/StatusLine';
import {RateLimits} from '../components/RateLimits';
import {DEMO, LIMITS_PACE} from '../data';
import {c} from '../theme';

export const DASHBOARD_DURATION = 480;

const HIGHLIGHT_FROM = 200;
const PACE_FROM = 340;

export const Dashboard: React.FC = () => {
  const frame = useCurrentFrame();

  // Bars sweep in one row at a time.
  const pacing = frame >= PACE_FROM;
  const rows = LIMITS_PACE.map((r, i) => ({
    ...r,
    // The projection is the last thing to land, once the bars have settled.
    proj: pacing ? r.proj : undefined,
    reveal: interpolate(frame, [30 + i * 22, 70 + i * 22], [0, 1], {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    }),
    highlight: pacing ? r.proj !== undefined : r.label === 'opus',
  }));

  const highlighting = frame >= HIGHLIGHT_FROM;

  return (
    <Scene durationInFrames={DASHBOARD_DURATION} gap={56}>
      <Terminal title="rate limits">
        <StatusLine {...DEMO.hot} fontSize={19} />
        <div style={{height: 34}} />
        <RateLimits rows={rows} dimNonHighlighted={highlighting} />
      </Terminal>

      <div style={{position: 'relative', width: 1340, height: 190}}>
        {!highlighting ? (
          <div style={{position: 'absolute', inset: 0}}>
            <Caption
              delay={110}
              title="A rate-limit dashboard, right in the status bar"
              body="Your 5-hour window, your 7-day window, and extra-usage credits — each with the exact time it resets, and each switchable on its own."
            />
          </div>
        ) : !pacing ? (
          <div style={{position: 'absolute', inset: 0}}>
            <Caption
              delay={HIGHLIGHT_FROM + 6}
              title="Including per-model weekly limits"
              body="Read from an undocumented field in the usage API. Claude Code's own UI does not show you these numbers anywhere."
              accent={c.green}
            />
          </div>
        ) : (
          <div style={{position: 'absolute', inset: 0}}>
            <Caption
              delay={PACE_FROM + 6}
              title="And where the window lands at this rate"
              body="38% two hours into a five-hour window is not 38% of a problem — it is a window that runs out before it resets. No state file, no extra request: the window opened at its own reset time minus its length."
              accent={c.orange}
            />
          </div>
        )}
      </div>
    </Scene>
  );
};
