import React from 'react';

/**
 * The ⚠ the script prints, drawn rather than typed. Emoji fonts hijack the
 * character into a colour glyph, which breaks both the monospace rhythm and
 * the escalation palette — an inline SVG renders the same on every machine.
 */
export const WarnGlyph: React.FC<{color: string; size?: number}> = ({
  color,
  size = 20,
}) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 24 24"
    style={{verticalAlign: '-0.15em'}}
    aria-hidden
  >
    <path
      d="M12 3 L22.5 21 H1.5 Z"
      fill="none"
      stroke={color}
      strokeWidth={2.2}
      strokeLinejoin="round"
    />
    <rect x="10.9" y="9" width="2.2" height="6.2" rx="1.1" fill={color} />
    <rect x="10.9" y="16.4" width="2.2" height="2.2" rx="1.1" fill={color} />
  </svg>
)
