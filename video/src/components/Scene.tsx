import React from 'react';
import {AbsoluteFill, interpolate, useCurrentFrame} from 'remotion';
import {c} from '../theme';

const FADE = 12;

/** Full-bleed scene wrapper with a shared cross-fade at both ends. */
export const Scene: React.FC<{
  durationInFrames: number;
  children: React.ReactNode;
  gap?: number;
}> = ({durationInFrames, children, gap = 60}) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(
    frame,
    [0, FADE, durationInFrames - FADE, durationInFrames],
    [0, 1, 1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );

  return (
    <AbsoluteFill
      style={{
        background: c.page,
        opacity,
        alignItems: 'center',
        justifyContent: 'center',
        flexDirection: 'column',
        gap,
        padding: 70,
      }}
    >
      {children}
    </AbsoluteFill>
  );
};
