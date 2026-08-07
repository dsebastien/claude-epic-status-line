import React from 'react';
import {AbsoluteFill, Series} from 'remotion';
import {loadFont as loadMono} from '@remotion/google-fonts/JetBrainsMono';
import {loadFont as loadSans} from '@remotion/google-fonts/Inter';
import {Hook, HOOK_DURATION} from './scenes/Hook';
import {Title, TITLE_DURATION} from './scenes/Title';
import {Anatomy, ANATOMY_DURATION} from './scenes/Anatomy';
import {Escalation, ESCALATION_DURATION} from './scenes/Escalation';
import {Dashboard, DASHBOARD_DURATION} from './scenes/Dashboard';
import {Config, CONFIG_DURATION} from './scenes/Config';
import {Install, INSTALL_DURATION} from './scenes/Install';
import {c} from './theme';

// Only the weights/subsets actually used — keeps font fetching cheap at render time.
loadMono('normal', {weights: ['400', '700'], subsets: ['latin']});
loadSans('normal', {weights: ['400', '700', '800'], subsets: ['latin']});

export const PROMO_DURATION =
  HOOK_DURATION +
  TITLE_DURATION +
  ANATOMY_DURATION +
  ESCALATION_DURATION +
  DASHBOARD_DURATION +
  CONFIG_DURATION +
  INSTALL_DURATION;

export const Promo: React.FC = () => (
  <AbsoluteFill style={{background: c.page}}>
    <Series>
      <Series.Sequence durationInFrames={HOOK_DURATION}>
        <Hook />
      </Series.Sequence>
      <Series.Sequence durationInFrames={TITLE_DURATION}>
        <Title />
      </Series.Sequence>
      <Series.Sequence durationInFrames={ANATOMY_DURATION}>
        <Anatomy />
      </Series.Sequence>
      <Series.Sequence durationInFrames={ESCALATION_DURATION}>
        <Escalation />
      </Series.Sequence>
      <Series.Sequence durationInFrames={DASHBOARD_DURATION}>
        <Dashboard />
      </Series.Sequence>
      <Series.Sequence durationInFrames={CONFIG_DURATION}>
        <Config />
      </Series.Sequence>
      <Series.Sequence durationInFrames={INSTALL_DURATION}>
        <Install />
      </Series.Sequence>
    </Series>
  </AbsoluteFill>
);
