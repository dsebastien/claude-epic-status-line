import React from 'react';
import {Sequence, useCurrentFrame} from 'remotion';
import {Scene} from '../components/Scene';
import {Terminal} from '../components/Terminal';
import {Caption} from '../components/Caption';
import {SegmentId, StatusLine} from '../components/StatusLine';
import {DEMO} from '../data';
import {c} from '../theme';

const BEAT = 115; // frames per segment

const BEATS: {id: SegmentId; title: string; body: string}[] = [
  {
    id: 'model',
    title: 'Model',
    body: 'Shortened, and coloured by family. Opus, Sonnet, Haiku and Fable each get their own hue, so you always know what you are talking to.',
  },
  {
    id: 'context',
    title: 'Context usage',
    body: 'Percentage and token counts. Dim while healthy — yellow at 70%, orange at 80% with a bold ⚠ (your cue to /compact), red at 90%.',
  },
  {
    id: 'git',
    title: 'Directory and git',
    body: 'Branch, staged / unstaged / untracked counts, ahead-behind arrows, and a ⎇wt marker inside worktrees. Invaluable with parallel sessions.',
  },
  {
    id: 'session',
    title: 'Cost, duration, diff',
    body: 'What this session has spent, how long you have been at it, and what it actually produced. Thresholds are yours to set.',
  },
  {
    id: 'effort',
    title: 'Effort and badges',
    body: 'Effort level, plus small markers for fast mode, thinking, a running subagent, or a non-default output style.',
  },
];

export const ANATOMY_DURATION = BEAT * BEATS.length;

export const Anatomy: React.FC = () => {
  const frame = useCurrentFrame();
  const index = Math.min(BEATS.length - 1, Math.floor(frame / BEAT));
  const active = BEATS[index];

  return (
    <Scene durationInFrames={ANATOMY_DURATION} gap={70}>
      <Terminal title="anatomy">
        <StatusLine {...DEMO.cruising} focus={active.id} />
      </Terminal>

      {/* Fixed-height slot so varying caption lengths never shift the terminal. */}
      <div style={{position: 'relative', width: 1300, height: 210}}>
        {BEATS.map((b, i) => (
          <Sequence
            key={b.id}
            from={i * BEAT}
            durationInFrames={BEAT}
            layout="none"
          >
            <div style={{position: 'absolute', inset: 0}}>
              <Caption title={b.title} body={b.body} accent={c.accent} />
            </div>
          </Sequence>
        ))}
      </div>
    </Scene>
  );
};
