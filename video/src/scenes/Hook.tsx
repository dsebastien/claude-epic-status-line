import React from 'react';
import {interpolate, useCurrentFrame} from 'remotion';
import {Scene} from '../components/Scene';
import {Terminal} from '../components/Terminal';
import {Caption} from '../components/Caption';
import {c, FONT_MONO} from '../theme';

export const HOOK_DURATION = 180;

/** Opens on Claude Code's stock status line, then names the problem. */
export const Hook: React.FC = () => {
  const frame = useCurrentFrame();
  const caret = Math.floor(frame / 15) % 2 === 0;

  return (
    <Scene durationInFrames={HOOK_DURATION}>
      <Terminal title="claude — default">
        <div
          style={{
            fontFamily: FONT_MONO,
            fontSize: 30,
            color: c.faint,
            opacity: interpolate(frame, [0, 20], [0, 1], {
              extrapolateRight: 'clamp',
            }),
          }}
        >
          ~/wks/my-project{caret ? ' ▏' : '  '}
        </div>
      </Terminal>

      <Caption
        delay={45}
        title="That is everything Claude Code tells you."
        body="No context budget. No cost. No idea how close you are to a rate limit."
        accent={c.text}
      />
    </Scene>
  );
};
