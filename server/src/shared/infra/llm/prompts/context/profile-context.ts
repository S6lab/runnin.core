import { UserProfile } from '@modules/users/domain/user.entity';

const FEEDBACK_LABELS: Record<string, string> = {
  pace: 'pace',
  bpm: 'frequência cardíaca',
  distance: 'distância',
  motivation: 'motivação',
  technique: 'técnica',
  hydration: 'hidratação',
  breathing: 'respiração',
};

export interface FeedbackFlags {
  enabled: Record<string, boolean>;
  inclusionRules: string;
  exclusionRules: string;
}

export function computeAge(birthDate?: string): number | undefined {
  if (!birthDate) return undefined;
  const d = new Date(birthDate);
  if (Number.isNaN(d.getTime())) return undefined;
  const ageMs = Date.now() - d.getTime();
  const years = Math.floor(ageMs / 31_557_600_000);
  return years > 0 && years < 120 ? years : undefined;
}

export function formatProfileContext(profile: Partial<UserProfile> | null | undefined): string {
  if (!profile) return '- Perfil não disponível.';

  const lines: string[] = [];
  if (profile.name) lines.push(`- Nome: ${profile.name}`);
  if (profile.gender) lines.push(`- Gênero: ${profile.gender}`);
  const age = computeAge(profile.birthDate);
  if (age) lines.push(`- Idade: ${age} anos`);
  if (profile.level) lines.push(`- Nível: ${profile.level}`);
  if (profile.goal) lines.push(`- Objetivo: ${profile.goal}`);
  if (profile.frequency) lines.push(`- Frequência alvo: ${profile.frequency} dias/semana`);
  if (profile.runPeriod) lines.push(`- Período preferido: ${profile.runPeriod}`);
  if (profile.wakeTime) lines.push(`- Acorda às: ${profile.wakeTime}`);
  if (profile.sleepTime) lines.push(`- Dorme às: ${profile.sleepTime}`);
  if (profile.weight) lines.push(`- Peso: ${profile.weight}`);
  if (profile.height) lines.push(`- Altura: ${profile.height}`);
  if (profile.restingBpm) lines.push(`- BPM repouso: ${profile.restingBpm}`);
  if (profile.maxBpm) lines.push(`- BPM máximo: ${profile.maxBpm}`);
  if (profile.hasWearable) lines.push('- Usa wearable.');
  if (profile.medicalConditions && profile.medicalConditions.length > 0) {
    lines.push(`- Condições: ${profile.medicalConditions.join(', ')}`);
  }
  if (profile.coachPersonality) lines.push(`- Persona escolhida: ${profile.coachPersonality}`);

  return lines.length > 0 ? lines.join('\n') : '- Perfil sem dados relevantes.';
}

export function formatFeedbackFlags(profile: Partial<UserProfile> | null | undefined): FeedbackFlags {
  const enabled = profile?.coachFeedbackEnabled ?? {};
  const on: string[] = [];
  const off: string[] = [];

  for (const [key, label] of Object.entries(FEEDBACK_LABELS)) {
    const value = enabled[key];
    if (value === false) off.push(label);
    else on.push(label);
  }

  return {
    enabled,
    inclusionRules: on.length > 0 ? `Pode comentar: ${on.join(', ')}.` : 'Não comente sobre nenhum tópico específico.',
    exclusionRules: off.length > 0 ? `NÃO comente sobre: ${off.join(', ')}.` : '',
  };
}

export function isInDndWindow(window?: { start: string; end: string }, now: Date = new Date()): boolean {
  if (!window?.start || !window?.end) return false;
  const cur = now.getHours() * 60 + now.getMinutes();
  const start = toMinutes(window.start);
  const end = toMinutes(window.end);
  if (start == null || end == null) return false;
  if (start === end) return false;
  if (start < end) return cur >= start && cur < end;
  return cur >= start || cur < end;
}

function toMinutes(hhmm: string): number | null {
  const m = /^(\d{1,2}):(\d{2})$/.exec(hhmm.trim());
  if (!m) return null;
  const h = Number(m[1]);
  const min = Number(m[2]);
  if (h < 0 || h > 23 || min < 0 || min > 59) return null;
  return h * 60 + min;
}
