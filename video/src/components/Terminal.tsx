import React from 'react';
import {c, FONT_MONO} from '../theme';

export const Terminal: React.FC<{
  title?: string;
  width?: number;
  children: React.ReactNode;
  style?: React.CSSProperties;
}> = ({title = 'claude', width = 1760, children, style}) => {
  return (
    <div
      style={{
        width,
        borderRadius: 14,
        background: c.card,
        border: `1px solid ${c.border}`,
        boxShadow: '0 40px 90px rgba(0,0,0,0.55)',
        overflow: 'hidden',
        ...style,
      }}
    >
      <div
        style={{
          height: 52,
          background: c.chrome,
          display: 'flex',
          alignItems: 'center',
          gap: 10,
          padding: '0 22px',
        }}
      >
        {['#ff5f57', '#febc2e', '#28c840'].map((dot) => (
          <div
            key={dot}
            style={{width: 13, height: 13, borderRadius: 999, background: dot}}
          />
        ))}
        <span
          style={{
            fontFamily: FONT_MONO,
            fontSize: 20,
            color: c.dim,
            marginLeft: 14,
          }}
        >
          {title}
        </span>
      </div>
      <div style={{padding: '34px 40px 38px'}}>{children}</div>
    </div>
  );
};
