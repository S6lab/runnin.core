export type CoachVoiceId = 'coach-bruno' | 'coach-clara' | 'coach-luna';

export interface CoachVoicePreset {
  id: CoachVoiceId;
  label: string;
  googleVoiceName: string;
  languageCode: string;
  speakingRate: number;
}

export const COACH_VOICE_PRESETS: Record<CoachVoiceId, CoachVoicePreset> = {
  'coach-bruno': {
    id: 'coach-bruno',
    label: 'Bruno',
    googleVoiceName: 'pt-BR-Neural2-B',
    languageCode: 'pt-BR',
    speakingRate: 1.08,
  },
  'coach-clara': {
    id: 'coach-clara',
    label: 'Clara',
    googleVoiceName: 'pt-BR-Neural2-A',
    languageCode: 'pt-BR',
    speakingRate: 1.06,
  },
  'coach-luna': {
    id: 'coach-luna',
    label: 'Luna',
    googleVoiceName: 'pt-BR-Neural2-C',
    languageCode: 'pt-BR',
    speakingRate: 1.08,
  },
};

export function resolveCoachVoicePreset(value: unknown): CoachVoicePreset | undefined {
  if (typeof value !== 'string') return undefined;
  return COACH_VOICE_PRESETS[value as CoachVoiceId];
}
