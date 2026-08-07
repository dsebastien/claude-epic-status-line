import React from 'react';
import {interpolate, useCurrentFrame} from 'remotion';
import {c, FONT_MONO} from '../theme';

export type CodeLine = {text: string; color?: string};

/** Types the block out line by line, then holds. */
export const CodeBlock: React.FC<{
  lines: CodeLine[];
  delay?: number;
  framesPerLine?: number;
  fontSize?: number;
}> = ({lines, delay = 0, framesPerLine = 18, fontSize = 30}) => {
  const frame = useCurrentFrame();

  return (
    <div
      style={{
        fontFamily: FONT_MONO,
        fontSize,
        lineHeight: 1.65,
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      {lines.map((l, i) => {
        const start = delay + i * framesPerLine;
        const opacity = interpolate(frame, [start, start + 10], [0, 1], {
          extrapolateLeft: 'clamp',
          extrapolateRight: 'clamp',
        });
        return (
          <span
            key={`${l.text}-${i}`}
            style={{
              opacity,
              color: l.color ?? c.text,
              minHeight: fontSize * 1.65,
              whiteSpace: 'pre',
            }}
          >
            {l.text}
          </span>
        );
      })}
    </div>
  );
};
