import React from 'react';
import {interpolate, useCurrentFrame} from 'remotion';
import {Scene} from '../components/Scene';
import {Terminal} from '../components/Terminal';
import {Caption} from '../components/Caption';
import {StatusLine} from '../components/StatusLine';
import {DEMO} from '../data';
import {c, escalate} from '../theme';

export const ESCALATION_DURATION = 300;

/** Drives the context percentage up through every threshold, live. */
export const Escalation: React.FC = () => {
  const frame = useCurrentFrame();

  const pct = Math.round(
    interpolate(frame, [20, 230], [38, 93], {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    }),
  );
  const used = `${Math.round((pct / 100) * 200)}k`;
  const cost = (1.87 + (pct - 38) * 0.42).toFixed(2);

  return (
    <Scene durationInFrames={ESCALATION_DURATION} gap={70}>
      <Terminal title="running hot">
        <StatusLine
          {...DEMO.cruising}
          contextPct={pct}
          contextUsed={used}
          cost={`$${cost}`}
          costColor={pct >= 80 ? c.red : c.green}
        />
      </Terminal>

      <Caption
        delay={10}
        title="Dim when healthy. Loud exactly where it matters."
        body="One escalation scale everywhere — context, rate limits, session cost. When something lights up, it means something."
        accent={escalate(pct)}
      />
    </Scene>
  );
};
