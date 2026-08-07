import React from 'react';
import {Scene} from '../components/Scene';
import {Terminal} from '../components/Terminal';
import {Caption} from '../components/Caption';
import {CodeBlock} from '../components/CodeBlock';
import {c} from '../theme';

export const CONFIG_DURATION = 270;

export const Config: React.FC = () => (
  <Scene durationInFrames={CONFIG_DURATION} gap={60}>
    <Terminal title="~/.config/claude-epic-status-line/config.sh" width={1400}>
      <CodeBlock
        delay={10}
        lines={[
          {text: '# every knob is optional — zero config works too', color: c.faint},
          {text: 'CESL_WARN=65                  # yellow kicks in earlier', color: c.text},
          {text: 'CESL_COST_CRIT=15             # red past $15/session', color: c.text},
          {text: 'CESL_GLYPHS=nerd              # unicode | nerd | ascii', color: c.text},
          {text: 'CESL_BAR_WIDTH=20', color: c.text},
          {text: 'CESL_SHOW_COST=0', color: c.text},
          {text: "CESL_CURRENCY_SYMBOL='€'", color: c.text},
          {text: "CESL_COLOR_OPUS='180;140;255'", color: c.text},
        ]}
      />
    </Terminal>

    <Caption
      delay={150}
      title="Make it yours — or change nothing at all"
      body="Thresholds, palette, model hues, bar width, glyph sets, per-segment toggles, currency. Script defaults, then your config file, then CESL_* environment variables on top."
    />
  </Scene>
);
