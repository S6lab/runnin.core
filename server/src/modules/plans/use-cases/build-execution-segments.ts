import { PlanSegment, PlanSession } from '../domain/plan.entity';
import {
  getRoteiroTemplatesDefault,
  RoteiroTemplates,
} from '@shared/knowledge/running/roteiro-templates.store';

/**
 * Gera o roteiro km-a-km (executionSegments) de uma sessão de forma
 * DETERMINÍSTICA — sem LLM. A MATEMÁTICA (fases, divisão de km, durações)
 * fica aqui; o TEXTO das instruções de cada fase vem do RAG editável
 * (Dossiê 4: roteiro-templates.json). Editar o template muda os roteiros.
 *
 * Variação: cada fase tem várias opções de redação no template — o builder
 * alterna entre elas por `rotation` (dia da semana) pra que sessões do mesmo
 * tipo em dias diferentes não fiquem idênticas.
 *
 * Sem LLM porque (a) salva quota, (b) é instantâneo e reproduzível, (c) o
 * conteúdo (estrutura + instrução por fase) é curado no RAG.
 */

interface InstrVars {
  km?: number;
  pace?: string | null;
  n?: number;
  total?: number;
}

/** Linha de pace pro placeholder {pace}: número quando há alvo, sensação senão. */
function paceToken(pace: string | null | undefined): string {
  return pace ? `pace alvo ${pace}/km` : 'ritmo pela sensação';
}

/**
 * Escolhe (deterministicamente) uma instrução do template para o tipo+fase e
 * substitui placeholders. `rotation` varia a opção entre sessões. Fallback
 * pra string genérica se o template não cobrir o tipo/fase.
 */
function instr(
  t: RoteiroTemplates,
  typeKey: string,
  phaseKey: string,
  rotation: number,
  vars: InstrVars = {},
): string {
  const opts = t[typeKey]?.phases?.[phaseKey];
  let text: string;
  if (opts && opts.length > 0) {
    const idx = ((rotation % opts.length) + opts.length) % opts.length;
    text = opts[idx]!;
  } else {
    text = vars.km != null
      ? `${t[typeKey]?.label ?? 'Sessão'} (${vars.km.toFixed(1)}km). {pace}.`
      : 'Siga a orientação do coach para esta fase. {pace}.';
  }
  return text
    .replace(/\{km\}/g, vars.km != null ? vars.km.toFixed(1) : '')
    .replace(/\{pace\}/g, paceToken(vars.pace))
    .replace(/\{n\}/g, vars.n != null ? String(vars.n) : '')
    .replace(/\{total\}/g, vars.total != null ? String(vars.total) : '');
}

/**
 * `templates`: por padrão usa o default versionado. Os use-cases passam o
 * override do Firestore (via getRoteiroTemplates) pra refletir edições do
 * admin sem deploy.
 */
export function buildExecutionSegments(
  session: PlanSession,
  templates: RoteiroTemplates = getRoteiroTemplatesDefault(),
): PlanSegment[] {
  const dist = session.distanceKm;
  if (!dist || dist <= 0) return [];

  const type = (session.type ?? '').toLowerCase();
  const pace = session.targetPace?.trim() || null;
  // Rotação estável por dia da semana → varia a redação entre sessões do
  // mesmo tipo sem virar aleatório (reproduzível).
  const rot = session.dayOfWeek ?? 1;
  const t = templates;

  if (type.includes('interval') || type.includes('tiro')) {
    return buildIntervalSegments(dist, pace, rot, t);
  }
  if (type.includes('tempo') || type.includes('limiar')) {
    return buildTempoSegments(dist, pace, rot, t);
  }
  if (type.includes('long') || type.includes('longão') || type.includes('longao')) {
    return buildLongSegments(dist, pace, rot, t);
  }
  if (type.includes('fartlek')) {
    return buildFartlekSegments(dist, pace, rot, t);
  }
  if (
    type.includes('recovery') ||
    type.includes('regenerativ') ||
    type.includes('recup')
  ) {
    return buildRecoverySegments(dist, pace, rot, t);
  }
  // default = easy / base / qualquer outro
  return buildEasySegments(dist, pace, rot, t);
}

function durationMinFromKm(km: number, pace: string | null, defaultMinPerKm: number): number {
  const minPerKm = parsePaceToMinPerKm(pace) ?? defaultMinPerKm;
  return Math.round(km * minPerKm * 10) / 10;
}

function parsePaceToMinPerKm(pace: string | null): number | null {
  if (!pace) return null;
  const m = pace.match(/^(\d+):(\d{1,2})/);
  if (!m) return null;
  const min = Number(m[1]);
  const sec = Number(m[2]);
  if (Number.isNaN(min) || Number.isNaN(sec)) return null;
  return min + sec / 60;
}

function buildEasySegments(dist: number, pace: string | null, rot: number, t: RoteiroTemplates): PlanSegment[] {
  if (dist < 3) {
    return [
      {
        kmStart: 0,
        kmEnd: dist,
        phase: 'main',
        targetPace: pace ?? undefined,
        durationMin: durationMinFromKm(dist, pace, 6.5),
        instruction: instr(t, 'easy', 'main_short', rot, { km: dist, pace }),
      },
    ];
  }
  const warmKm = 1;
  const coolKm = 1;
  const mainKm = round1(dist - warmKm - coolKm);
  return [
    {
      kmStart: 0,
      kmEnd: warmKm,
      phase: 'warmup',
      durationMin: durationMinFromKm(warmKm, null, 7.5),
      instruction: instr(t, 'easy', 'warmup', rot),
    },
    {
      kmStart: warmKm,
      kmEnd: round1(warmKm + mainKm),
      phase: 'main',
      targetPace: pace ?? undefined,
      durationMin: durationMinFromKm(mainKm, pace, 6.5),
      instruction: instr(t, 'easy', 'main', rot, { km: mainKm, pace }),
    },
    {
      kmStart: round1(warmKm + mainKm),
      kmEnd: dist,
      phase: 'cooldown',
      durationMin: durationMinFromKm(coolKm, null, 7.5),
      instruction: instr(t, 'easy', 'cooldown', rot),
    },
  ];
}

function buildTempoSegments(dist: number, pace: string | null, rot: number, t: RoteiroTemplates): PlanSegment[] {
  const warmKm = Math.min(1.5, Math.max(1, dist * 0.2));
  const coolKm = 1;
  const tempoKm = round1(dist - warmKm - coolKm);
  if (tempoKm <= 0) {
    return buildEasySegments(dist, pace, rot, t);
  }
  return [
    {
      kmStart: 0,
      kmEnd: round1(warmKm),
      phase: 'warmup',
      durationMin: durationMinFromKm(warmKm, null, 7.0),
      instruction: instr(t, 'tempo', 'warmup', rot),
    },
    {
      kmStart: round1(warmKm),
      kmEnd: round1(warmKm + tempoKm),
      phase: 'main',
      targetPace: pace ?? undefined,
      durationMin: durationMinFromKm(tempoKm, pace, 5.5),
      instruction: instr(t, 'tempo', 'main', rot, { km: tempoKm, pace }),
    },
    {
      kmStart: round1(warmKm + tempoKm),
      kmEnd: dist,
      phase: 'cooldown',
      durationMin: durationMinFromKm(coolKm, null, 7.5),
      instruction: instr(t, 'tempo', 'cooldown', rot),
    },
  ];
}

function buildLongSegments(dist: number, pace: string | null, rot: number, t: RoteiroTemplates): PlanSegment[] {
  const warmKm = 1;
  const coolKm = 1;
  const remaining = dist - warmKm - coolKm;
  if (remaining <= 0) return buildEasySegments(dist, pace, rot, t);
  const baseKm = round1(remaining * 0.7);
  const finishKm = round1(remaining - baseKm);
  return [
    {
      kmStart: 0,
      kmEnd: warmKm,
      phase: 'warmup',
      durationMin: durationMinFromKm(warmKm, null, 8.0),
      instruction: instr(t, 'long', 'warmup', rot),
    },
    {
      kmStart: warmKm,
      kmEnd: round1(warmKm + baseKm),
      phase: 'main',
      targetPace: pace ?? undefined,
      durationMin: durationMinFromKm(baseKm, pace, 7.0),
      instruction: instr(t, 'long', 'main_base', rot, { km: baseKm, pace }),
    },
    {
      kmStart: round1(warmKm + baseKm),
      kmEnd: round1(warmKm + baseKm + finishKm),
      phase: 'main',
      targetPace: pace ?? undefined,
      durationMin: durationMinFromKm(finishKm, pace, 6.7),
      instruction: instr(t, 'long', 'main_finish', rot, { km: finishKm, pace }),
    },
    {
      kmStart: round1(warmKm + baseKm + finishKm),
      kmEnd: dist,
      phase: 'cooldown',
      durationMin: durationMinFromKm(coolKm, null, 8.5),
      instruction: instr(t, 'long', 'cooldown', rot),
    },
  ];
}

function buildIntervalSegments(dist: number, pace: string | null, rot: number, t: RoteiroTemplates): PlanSegment[] {
  const warmKm = 1.5;
  const coolKm = 1;
  const remaining = dist - warmKm - coolKm;
  if (remaining <= 0.8) return buildEasySegments(dist, pace, rot, t);
  const cycles = Math.max(3, Math.min(10, Math.floor(remaining / 0.6)));
  const segments: PlanSegment[] = [];
  segments.push({
    kmStart: 0,
    kmEnd: warmKm,
    phase: 'warmup',
    durationMin: durationMinFromKm(warmKm, null, 7.0),
    instruction: instr(t, 'interval', 'warmup', rot),
  });
  let cursor = warmKm;
  for (let i = 0; i < cycles; i++) {
    const repPace = pace;
    segments.push({
      kmStart: round1(cursor),
      kmEnd: round1(cursor + 0.4),
      phase: 'interval',
      targetPace: repPace ?? undefined,
      durationMin: durationMinFromKm(0.4, repPace, 4.0),
      instruction: instr(t, 'interval', 'rep', rot + i, { n: i + 1, total: cycles, pace: repPace }),
    });
    cursor += 0.4;
    segments.push({
      kmStart: round1(cursor),
      kmEnd: round1(cursor + 0.2),
      phase: 'recovery',
      durationMin: durationMinFromKm(0.2, null, 9.0),
      instruction: instr(t, 'interval', 'recovery', rot + i, { n: i + 1, total: cycles }),
    });
    cursor += 0.2;
  }
  segments.push({
    kmStart: round1(cursor),
    kmEnd: dist,
    phase: 'cooldown',
    durationMin: durationMinFromKm(coolKm, null, 8.0),
    instruction: instr(t, 'interval', 'cooldown', rot),
  });
  return segments;
}

function buildRecoverySegments(dist: number, pace: string | null, rot: number, t: RoteiroTemplates): PlanSegment[] {
  return [
    {
      kmStart: 0,
      kmEnd: dist,
      phase: 'recovery',
      targetPace: pace ?? undefined,
      durationMin: durationMinFromKm(dist, pace, 7.5),
      instruction: instr(t, 'recovery', 'main', rot, { km: dist, pace }),
    },
  ];
}

function buildFartlekSegments(dist: number, pace: string | null, rot: number, t: RoteiroTemplates): PlanSegment[] {
  const warmKm = Math.min(1.5, Math.max(1, dist * 0.2));
  const coolKm = 1;
  const mainKm = round1(dist - warmKm - coolKm);
  if (mainKm <= 0) return buildEasySegments(dist, pace, rot, t);
  return [
    {
      kmStart: 0,
      kmEnd: round1(warmKm),
      phase: 'warmup',
      durationMin: durationMinFromKm(warmKm, null, 7.0),
      instruction: instr(t, 'fartlek', 'warmup', rot),
    },
    {
      kmStart: round1(warmKm),
      kmEnd: round1(warmKm + mainKm),
      phase: 'main',
      targetPace: pace ?? undefined,
      durationMin: durationMinFromKm(mainKm, pace, 6.0),
      instruction: instr(t, 'fartlek', 'main', rot, { km: mainKm, pace }),
    },
    {
      kmStart: round1(warmKm + mainKm),
      kmEnd: dist,
      phase: 'cooldown',
      durationMin: durationMinFromKm(coolKm, null, 7.5),
      instruction: instr(t, 'fartlek', 'cooldown', rot),
    },
  ];
}

function round1(n: number): number {
  return Math.round(n * 10) / 10;
}
