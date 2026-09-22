import {StatusLineProps} from './components/StatusLine';
import {LimitRow} from './components/RateLimits';
import {c} from './theme';

/** The states from the project README screenshot, kept in sync with it. */
export const DEMO: Record<'cruising' | 'hot' | 'big', StatusLineProps> = {
  cruising: {
    model: 'Fable 5',
    modelColor: c.fable,
    contextPct: 38,
    contextUsed: '76k',
    contextTotal: '200k',
    dir: '…/wks/my-project',
    branch: 'feature/epic-v2',
    staged: 1,
    untracked: 2,
    cost: '$1.87',
    costColor: c.green,
    duration: '1h31m',
    added: 156,
    removed: 23,
    turn: '7.6k',
    turns: 34,
    effort: 'high',
  },
  hot: {
    model: 'Opus 5',
    modelColor: c.opus,
    contextPct: 85,
    contextUsed: '170k',
    contextTotal: '200k',
    dir: '…/my-project',
    branch: 'feature/epic-v2',
    staged: 1,
    untracked: 2,
    cost: '$23.40',
    costColor: c.red,
    duration: '3h15m',
    added: 2431,
    removed: 890,
    turn: '17k',
    turnColor: c.red,
    turns: 162,
    effort: 'max',
    badges: ['fast'],
  },
  /** The case a percentage cannot describe: half a 1M window, 48k a turn. */
  big: {
    model: 'Opus 5 (1M context)',
    modelColor: c.opus,
    contextPct: 48,
    contextUsed: '486k',
    contextTotal: '1.0m',
    dir: '…/my-project',
    branch: 'feature/epic-v2',
    staged: 1,
    untracked: 2,
    cost: '$18.20',
    costColor: c.orange,
    duration: '4h02m',
    added: 3180,
    removed: 1204,
    turn: '48k',
    turnColor: c.red,
    turns: 188,
    effort: 'high',
  },
};

export const LIMITS_COOL: LimitRow[] = [
  {label: '5-hour', pct: 38, reset: '10:00pm'},
  {label: '7-day', pct: 29, reset: 'aug 9'},
  {label: 'fable', pct: 41, reset: 'aug 6'},
  {label: 'extra', pct: 25, value: '$12.40/$50.00', reset: 'sep 1'},
];

export const LIMITS_HOT: LimitRow[] = [
  {label: '5-hour', pct: 91, reset: '10:00pm'},
  {label: '7-day', pct: 74, reset: 'aug 9'},
  {label: 'fable', pct: 41, reset: 'aug 6'},
  {label: 'extra', pct: 25, value: '$12.40/$50.00', reset: 'sep 1'},
];

/**
 * Mid-window, and the pace is the story: 38% two hours into a five-hour
 * window lands at 94%, so the window runs out before it resets.
 */
export const LIMITS_PACE: LimitRow[] = [
  {label: '5-hour', pct: 38, reset: '2:42pm', proj: 94},
  {label: '7-day', pct: 52, reset: 'sep 25', proj: 88},
  {label: 'opus', pct: 41, reset: 'sep 26'},
  {label: 'extra', pct: 25, value: '$12.40/$50.00', reset: 'oct 1'},
];
