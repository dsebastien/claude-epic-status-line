import React from 'react';
import {c, escalate, FONT_MONO} from '../theme';

export type SegmentId = 'model' | 'context' | 'git' | 'session' | 'effort';

export type StatusLineProps = {
  model: string;
  modelColor: string;
  contextPct: number;
  contextUsed: string;
  contextTotal: string;
  dir: string;
  branch: string;
  staged: number;
  untracked: number;
  cost: string;
  costColor?: string;
  duration: string;
  added: number;
  removed: number;
  effort: string;
  badges?: string[];
  /** When set, every other segment dims out so the eye lands on this one. */
  focus?: SegmentId | null;
  fontSize?: number;
};

const SEP = (
  <span style={{color: c.faint, padding: '0 10px'}}>│</span>
);

export const StatusLine: React.FC<StatusLineProps> = ({
  model,
  modelColor,
  contextPct,
  contextUsed,
  contextTotal,
  dir,
  branch,
  staged,
  untracked,
  cost,
  costColor,
  duration,
  added,
  removed,
  effort,
  badges = [],
  focus = null,
  fontSize = 24,
}) => {
  const op = (id: SegmentId): number => (focus === null || focus === id ? 1 : 0.22);
  const ctxColor = escalate(contextPct);
  const warn = contextPct >= 80;

  return (
    <div
      style={{
        fontFamily: FONT_MONO,
        fontSize,
        color: c.text,
        whiteSpace: 'nowrap',
        display: 'flex',
        alignItems: 'center',
        letterSpacing: 0.2,
      }}
    >
      <span style={{color: modelColor, opacity: op('model')}}>{model}</span>
      {SEP}

      <span style={{opacity: op('context')}}>
        {warn ? <span style={{color: ctxColor, fontWeight: 700}}>⚠ </span> : null}
        <span style={{color: ctxColor}}>{contextPct}%</span>
        <span style={{color: c.dim}}>
          {' '}
          ({contextUsed}/{contextTotal})
        </span>
      </span>
      {SEP}

      <span style={{opacity: op('git')}}>
        <span style={{color: c.dim}}>{dir}</span>
        <span style={{color: c.faint}}> (</span>
        <span style={{color: c.dim}}>{branch}</span>
        {staged > 0 ? <span style={{color: c.green}}> S:{staged}</span> : null}
        {untracked > 0 ? <span style={{color: c.red}}> A:{untracked}</span> : null}
        <span style={{color: c.faint}}>)</span>
      </span>
      {SEP}

      <span style={{opacity: op('session')}}>
        <span style={{color: costColor ?? c.green}}>{cost}</span>
        <span style={{color: c.faint}}> · </span>
        <span style={{color: c.text}}>{duration}</span>
        <span style={{color: c.faint}}> · </span>
        <span style={{color: c.dim}}>
          +{added}/-{removed}
        </span>
      </span>

      <span style={{opacity: op('effort')}}>
        <span style={{color: c.faint}}> · </span>
        <span style={{color: c.dim}}>● {effort}</span>
        {badges.map((b) => (
          <React.Fragment key={b}>
            <span style={{color: c.faint}}> · </span>
            <span style={{color: b.startsWith('[') ? c.sonnet : c.dim}}>{b}</span>
          </React.Fragment>
        ))}
      </span>
    </div>
  );
};
