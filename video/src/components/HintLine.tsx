import React from 'react';
import {c, FONT_MONO} from '../theme';
import {WarnGlyph} from './WarnGlyph';

/**
 * The hint line the script prints under the dashboard: an alert glyph plus
 * the instruction, in the same monospace as everything else.
 */
export const HintLine: React.FC<{
  text: string;
  accent?: string;
  fontSize?: number;
  opacity?: number;
}> = ({text, accent = c.red, fontSize = 24, opacity = 1}) => (
  <div
    style={{
      fontFamily: FONT_MONO,
      fontSize,
      color: c.text,
      whiteSpace: 'nowrap',
      opacity,
    }}
  >
    <WarnGlyph color={accent} size={fontSize * 0.92} />{' '}
    {text}
  </div>
);
