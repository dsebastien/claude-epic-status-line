import React from 'react';
import {interpolate, useCurrentFrame} from 'remotion';
import {Scene} from '../components/Scene';
import {Terminal} from '../components/Terminal';
import {Caption} from '../components/Caption';
import {StatusLine} from '../components/StatusLine';
import {HintLine} from '../components/HintLine';
import {DEMO} from '../data';
import {c} from '../theme';

export const TURN_DURATION = 360;

const HINT_FROM = 200;

const fmtTokens = (n: number): string =>
  n >= 1_000_000 ? `${(n / 1_000_000).toFixed(1)}m` : `${Math.floor(n / 1000)}k`;

/**
 * The case a percentage cannot describe. The window fills slowly and stays
 * green; the per-turn cost climbs through yellow into red at the same time.
 */
export const Turn: React.FC = () => {
  const frame = useCurrentFrame();

  const ctx = Math.round(
    interpolate(frame, [15, HINT_FROM], [120_000, 486_000], {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    }),
  );
  const turnTokens = Math.round(ctx * 0.1);
  const pct = Math.round((ctx / 1_000_000) * 100);

  // Absolute token thresholds, not a percentage — the whole point of the scene.
  const turnColor = ctx >= 120_000 ? c.red : ctx >= 60_000 ? c.yellow : c.green;

  const hintOpacity = interpolate(frame, [HINT_FROM, HINT_FROM + 20], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <Scene durationInFrames={TURN_DURATION} gap={60}>
      <Terminal title="the number that bites">
        <StatusLine
          {...DEMO.big}
          contextPct={pct}
          contextUsed={fmtTokens(ctx)}
          turn={fmtTokens(turnTokens)}
          turnColor={turnColor}
          fontSize={19}
        />
        <div style={{height: 30}} />
        <HintLine
          opacity={hintOpacity}
          text="486k context — every turn re-sends it at 48k before you type — /clear between tasks"
        />
      </Terminal>

      <div style={{position: 'relative', width: 1340, height: 200}}>
        {frame < HINT_FROM ? (
          <div style={{position: 'absolute', inset: 0}}>
            <Caption
              delay={20}
              title="Half a window full. 48k on every single turn."
              body="The API is stateless, so each turn re-sends the whole conversation before you type a character. A percentage cannot tell you that — 486k of a 1M window reads as comfortable."
              accent={c.red}
            />
          </div>
        ) : (
          <div style={{position: 'absolute', inset: 0}}>
            <Caption
              delay={HINT_FROM + 8}
              title="And it names the right command"
              body="/compact when the window is nearly full. /clear when the session is merely expensive — compacting a half-empty window misses the point."
              accent={c.green}
            />
          </div>
        )}
      </div>
    </Scene>
  );
};
