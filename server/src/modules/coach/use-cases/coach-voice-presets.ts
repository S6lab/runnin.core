// Voz ÚNICA do Coach (decisão de produto / Doc 5): uma voz masculina pt-BR.
// O atleta escolhe só a PERSONA (Motivador/Técnico), não a voz.
export type CoachVoiceId = 'coach-bruno';

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
};

/** Sempre resolve a voz única (defensivo contra ids legados clara/luna). */
export function resolveCoachVoicePreset(_value?: unknown): CoachVoicePreset {
  return COACH_VOICE_PRESETS['coach-bruno'];
}
