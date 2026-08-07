import {StatusLineProps} from './components/StatusLine';
import {LimitRow} from './components/RateLimits';
import {c} from './theme';

/** The two states from the project README screenshot, kept in sync with it. */
export const DEMO: Record<'cruising' | 'hot', StatusLineProps> = {
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
    effort: 'high',
  },
  hot: {
    model: 'Opus 5',
    modelColor: c.opus,
    contextPct: 85,
    contextUsed: '170k',
    contextTotal: '200k',
    dir: '…/wks/my-project',
    branch: 'feature/epic-v2',
    staged: 1,
    untracked: 2,
    cost: '$23.40',
    costColor: c.red,
    duration: '3h15m',
    added: 2431,
    removed: 890,
    effort: 'max',
    badges: ['fast', '[code-reviewer]'],
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
