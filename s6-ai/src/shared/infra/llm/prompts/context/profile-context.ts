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
  // Fix TF 60: parser robusto. Antes só new Date(birthDate) — falha em
  // formato BR "18/02/1983" (Invalid Date) → coach LLM chuta idade.
  // Aceita: ISO "1983-02-18", BR "18/02/1983", BR "18/02/83".
  const d = _parseBirthDate(birthDate);
  if (!d || Number.isNaN(d.getTime())) return undefined;
  // Aniversário ainda não chegou esse ano? Subtrai 1.
  const now = new Date();
  let years = now.getFullYear() - d.getFullYear();
  const monthDiff = now.getMonth() - d.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && now.getDate() < d.getDate())) {
    years--;
  }
  return years > 0 && years < 120 ? years : undefined;
}

function _parseBirthDate(s: string): Date | null {
  // ISO "1983-02-18" ou "1983-02-18T..."
  const iso = /^(\d{4})-(\d{1,2})-(\d{1,2})/.exec(s);
  if (iso) {
    return new Date(Number(iso[1]), Number(iso[2]) - 1, Number(iso[3]));
  }
  // BR "18/02/1983" ou "18/02/83"
  const br = /^(\d{1,2})\/(\d{1,2})\/(\d{2,4})$/.exec(s);
  if (br) {
    let y = Number(br[3]);
    if (y < 100) y += y < 30 ? 2000 : 1900; // 25 → 2025, 80 → 1980
    return new Date(y, Number(br[2]) - 1, Number(br[1]));
  }
  // Fallback: deixa Date tentar (ISO datetime extendido etc).
  const d = new Date(s);
  return Number.isNaN(d.getTime()) ? null : d;
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

/**
 * Bloco contextual com a telemetria do wearable (últimos N dias).
 * Quando há `restingBpm` + `maxBpm` no perfil + sampleCount > 0, instrui o
 * LLM a calibrar zonas pela fórmula de Karvonen em vez de usar estimativas
 * por idade (220 - age) e a posicionar long runs em Z2. Sem esses dados,
 * retorna string vazia — caller não injeta seção alguma no prompt.
 *
 * `summary` é a saída do GetSummaryUseCase (janela default 7 dias).
 */
export interface BiometricContextInput {
  restingBpm?: number;
  maxBpm?: number;
  summary?: {
    windowDays: number;
    avgRestingBpm: number | null;
    maxBpm: number | null;
    avgSleepHours: number | null;
    totalSteps: number | null;
    avgHrv: number | null;
    latestWeight: number | null;
    avgSpo2?: number | null;
    avgRespiratoryRate?: number | null;
    latestBodyFatPct?: number | null;
    sampleCount: number;
  } | null;
}

export function formatBiometricContext(args: BiometricContextInput): string {
  const { restingBpm, maxBpm, summary } = args;
  const hasProfileBpm = !!(restingBpm && maxBpm);
  const hasSamples = !!(summary && summary.sampleCount > 0);
  if (!hasProfileBpm && !hasSamples) return '';

  const lines: string[] = ['DADOS BIOMÉTRICOS DO WEARABLE — use pra personalizar:'];
  if (restingBpm) lines.push(`- FC repouso (perfil): ${restingBpm} bpm`);
  if (maxBpm) lines.push(`- FC máxima (perfil): ${maxBpm} bpm`);
  if (summary) {
    const w = summary.windowDays;
    if (summary.avgRestingBpm) lines.push(`- FC repouso média ${w}d: ${summary.avgRestingBpm.toFixed(0)} bpm`);
    if (summary.maxBpm) lines.push(`- FC máxima vista ${w}d: ${summary.maxBpm.toFixed(0)} bpm`);
    if (summary.avgHrv) lines.push(`- HRV média ${w}d: ${summary.avgHrv.toFixed(0)} ms`);
    if (summary.avgSleepHours) lines.push(`- Sono médio ${w}d: ${summary.avgSleepHours.toFixed(1)} h/noite`);
    if (summary.totalSteps) lines.push(`- Passos ${w}d: ${summary.totalSteps.toFixed(0)}`);
    if (summary.latestWeight) lines.push(`- Peso atual: ${summary.latestWeight.toFixed(1)} kg`);
    if (summary.avgSpo2) lines.push(`- SpO2 média ${w}d: ${summary.avgSpo2.toFixed(1)}%`);
    if (summary.avgRespiratoryRate) {
      lines.push(`- Freq. respiratória média ${w}d: ${summary.avgRespiratoryRate.toFixed(1)} rpm`);
    }
    if (summary.latestBodyFatPct) {
      lines.push(`- Gordura corporal: ${summary.latestBodyFatPct.toFixed(1)}%`);
    }
    lines.push(`- Amostras recebidas no período: ${summary.sampleCount}`);
  }

  if (hasProfileBpm) {
    lines.push('');
    lines.push('INSTRUÇÕES DE USO:');
    lines.push(
      `- Zonas cardíacas: use Karvonen (HRR) com restingBpm=${restingBpm} e maxBpm=${maxBpm} — NÃO use a estimativa 220-idade. Z2 (60-70% HRR) = ${Math.round((maxBpm! - restingBpm!) * 0.6 + restingBpm!)}-${Math.round((maxBpm! - restingBpm!) * 0.7 + restingBpm!)} bpm; Z4 (80-90% HRR) = ${Math.round((maxBpm! - restingBpm!) * 0.8 + restingBpm!)}-${Math.round((maxBpm! - restingBpm!) * 0.9 + restingBpm!)} bpm.`,
    );
    lines.push('- Long runs e Easy Runs devem indicar pace + alvo de FC em Z2 nas notes.');
  }
  if (summary?.avgHrv) {
    lines.push(
      `- HRV ${summary.avgHrv.toFixed(0)}ms: se vier deprimida em revisões semanais (queda >15% vs baseline), reduzir intensidade ou adicionar deload. Use como input nos checkpoints.`,
    );
  }
  if (summary?.avgSpo2 && summary.avgSpo2 < 95) {
    lines.push(
      `- SpO2 média ${summary.avgSpo2.toFixed(1)}% abaixo do esperado (~95%+) — possível doença/overtraining/altitude. Comece conservador e cite o dado na rationale.`,
    );
  }
  if (summary?.avgSleepHours) {
    const h = summary.avgSleepHours;
    if (h < 6.5) {
      lines.push(
        `- Sono médio ${h.toFixed(1)}h/noite é INSUFICIENTE pro nível de carga proposto. Cite na notes da semana 1: "${h.toFixed(1)}h de sono em média — recuperação comprometida; priorize ${Math.ceil(7 - h)}h extras antes de subir volume." Considere taper extra no DELOAD.`,
      );
    } else if (h > 8) {
      lines.push(`- Sono ${h.toFixed(1)}h/noite OK — recuperação adequada pra plano de carga progressiva.`);
    }
  }
  return lines.join('\n');
}

export function formatFeedbackFlags(
  profile: Partial<UserProfile> | null | undefined,
  opts: { respectToggles?: boolean } = {},
): FeedbackFlags {
  // Quando o knob `respectFeedbackToggles` está OFF, ignoramos os toggles
  // do user e devolvemos "sem restrição" — coach comenta tudo. ON (default)
  // respeita `profile.coachFeedbackEnabled`.
  const respect = opts.respectToggles ?? true;
  if (!respect) {
    const allOn = Object.keys(FEEDBACK_LABELS).reduce<Record<string, boolean>>((acc, k) => {
      acc[k] = true;
      return acc;
    }, {});
    return {
      enabled: allOn,
      inclusionRules: 'Pode comentar sobre todos os tópicos (toggles do user ignorados pelo knob).',
      exclusionRules: '',
    };
  }
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
