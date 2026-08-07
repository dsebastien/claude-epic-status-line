import React from 'react';
import {interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {Scene} from '../components/Scene';
import {Terminal} from '../components/Terminal';
import {CodeBlock} from '../components/CodeBlock';
import {c, FONT_MONO} from '../theme';

export const INSTALL_DURATION = 300;

export const Install: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const cta = spring({frame: frame - 150, fps, config: {damping: 200}});

  return (
    <Scene durationInFrames={INSTALL_DURATION} gap={60}>
      <div
        style={{
          fontFamily: 'Inter, system-ui, sans-serif',
          fontSize: 56,
          fontWeight: 700,
          color: c.text,
          opacity: interpolate(frame, [0, 20], [0, 1], {
            extrapolateRight: 'clamp',
          }),
        }}
      >
        Three commands. Linux and macOS.
      </div>

      <Terminal title="install" width={1400}>
        <CodeBlock
          delay={25}
          framesPerLine={26}
          lines={[
            {
              text: '$ git clone https://github.com/dsebastien/claude-epic-status-line.git',
              color: c.green,
            },
            {text: '$ cd claude-epic-status-line', color: c.green},
            {text: '$ bash install.sh', color: c.green},
            {text: '', color: c.dim},
            {text: '✓ backed up your existing status line', color: c.dim},
            {text: '✓ scaffolded ~/.config/claude-epic-status-line/config.sh', color: c.dim},
            {text: '✓ wired up ~/.claude/settings.json', color: c.dim},
          ]}
        />
      </Terminal>

      <div
        style={{
          opacity: cta,
          transform: `translateY(${interpolate(cta, [0, 1], [24, 0])}px)`,
          textAlign: 'center',
        }}
      >
        <div
          style={{
            fontFamily: FONT_MONO,
            fontSize: 38,
            color: c.accent,
          }}
        >
          github.com/dsebastien/claude-epic-status-line
        </div>
        <div
          style={{
            fontFamily: 'Inter, system-ui, sans-serif',
            fontSize: 28,
            color: c.faint,
            marginTop: 14,
          }}
        >
          Needs only jq, curl and git. MIT licensed. PRs welcome.
        </div>
      </div>
    </Scene>
  );
};
