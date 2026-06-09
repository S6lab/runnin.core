import { v4 as uuid } from 'uuid';
import {
  Plan,
  PlanRevision as PlanRevisionLog,
  PlanSession,
  PlanWeek,
  effectivePlanWeeks,
} from '../domain/plan.entity';
import { buildExecutionSegments, resolveEffectiveSessionType } from './build-execution-segments';
import {
  getRoteiroTemplates,
  RoteiroTemplates,
} from '@shared/knowledge/running/roteiro-templates.store';
import { PlanRevision } from '../domain/plan-revision.entity';
import { CheckpointInput } from '../domain/plan-checkpoint.entity';
import { RunRepository } from '@modules/runs/domain/run.repository';
import { Run } from '@modules/runs/domain/run.entity';
import {
  CheckpointAnalysisStrategy,
  CheckpointWeekMetrics,
  CheckpointWeekRun,
} from './checkpoint-analysis.strategy';
import { AppError } from '@shared/errors/app-error';
import { BiometricSummary } from '@modules/biometrics/use-cases/get-summary.use-case';
import { logger } from '@shared/logger/logger';

/**
 * Rede de proteção: o runnin é app de CORRIDA — só corrida (suas variações)
 * + Caminhada podem virar sessão do plano. Mesmo com a regra dura nos prompts
 * (plan-init, plan-revision, checkpoint), o LLM ocasionalmente devolve type
 * proibido (Ciclismo, Natação, Elíptico, Musculação). Esta função normaliza
 * antes de salvar: type proibido vira "Caminhada" e a distância é clamp em
 * 5km (caminhada longa razoável). Loga toda conversão pra rastrear regressão
 * no prompt.
 *
 * Lista de termos proibidos é case/diacritic-insensitive.
 */
const _forbiddenSessionTypeTerms = [
  'ciclism', 'biciclet', 'bike', 'cycling', 'cycle', 'pedal',
  'natac', 'swim', 'piscina',
  'eliptic', 'elliptic',
  'remo', 'rowing',
  'musculac', 'strength', 'forca', 'weight',
  'crossfit', 'yoga', 'pilates',
];

/** Pace médio em min/km ponderado pela DISTÂNCIA total — espelha a fórmula
 *  do history page (totalS / totalDist). Antes era média aritmética simples
 *  e divergia do app (9:11 server vs 8:26 history pra mesma janela). */
function weightedPace(runs: Array<{ distanceKm: number; durationS: number }>): number | undefined {
  const totalDist = runs.reduce((s, r) => s + r.distanceKm, 0);
  const totalDur = runs.reduce((s, r) => s + r.durationS, 0);
  if (totalDist <= 0 || totalDur <= 0) return undefined;
  return (totalDur / 60) / totalDist;
}

function _normalizeText(s: string): string {
  // Strip combining diacriticals (U+0300..U+036F) — usar \u escape em vez
  // de caracteres literais pra não depender de bytes invisíveis no source.
  return s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
}

export function sanitizeSessionType(
  rawType: string,
  distanceKm: number,
  ctx: { planId?: string; weekNumber?: number; dayOfWeek?: number } = {},
): { type: string; distanceKm: number; wasNormalized: boolean } {
  const norm = _normalizeText(rawType);
  const hit = _forbiddenSessionTypeTerms.find((t) => norm.includes(t));
  if (!hit) return { type: rawType, distanceKm, wasNormalized: false };
  const clampedDistance = Math.min(distanceKm, 5);
  logger.warn('plan.session.type.normalized', {
    rawType,
    hit,
    distanceKm,
    clampedDistance,
    ...ctx,
  });
  return { type: 'Caminhada', distanceKm: clampedDistance, wasNormalized: true };
}

/** Allowlist por nível. Iniciante NÃO PODE Fartlek/Intervalado/Tempo/Tiros —
 *  exigem base aeróbica + técnica de respiração que o iniciante não tem;
 *  prescrever é convidar lesão e frustração. */
const _ALLOWED_BY_LEVEL: Record<string, RegExp[]> = {
  iniciante: [
    /\beasy\b/i, /\blong\b/i, /\brecovery\b/i, /\bregenerat/i,
    /\bcaminhada\b/i, /\bprogress/i,
  ],
  intermediario: [
    /\beasy\b/i, /\blong\b/i, /\brecovery\b/i, /\bregenerat/i,
    /\bcaminhada\b/i, /\bprogress/i, /\btempo\b/i, /\bfartlek\b/i, /\blimiar\b/i,
  ],
  avancado: [/.*/], // tudo
};

/** Mapeia tipos não permitidos pro level pra alternativas seguras.
 *  Fartlek/Tempo → Progressivo (variação leve, mantém intenção de variar).
 *  Intervalado/Tiros → Easy Run (sem qualidade — iniciante não tem base). */
function _downgradeToSafe(rawType: string): string {
  const t = rawType.toLowerCase();
  if (t.includes('fartlek') || t.includes('tempo') || t.includes('limiar')) return 'Progressivo';
  if (t.includes('intervalado') || t.includes('interval') || t.includes('tiro')) return 'Easy Run';
  return 'Easy Run';
}

/** Verifica + corrige type por nível. Loga substituição. */
export function enforceLevelTypeAllowlist(
  rawType: string,
  level: string | undefined,
  ctx: { planId?: string; weekNumber?: number; dayOfWeek?: number } = {},
): { type: string; wasDowngraded: boolean } {
  const lvl = (level ?? 'iniciante').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
  const allowed = _ALLOWED_BY_LEVEL[lvl] ?? _ALLOWED_BY_LEVEL.iniciante!;
  const normRaw = rawType.toLowerCase();
  const ok = allowed.some((rx) => rx.test(normRaw));
  if (ok) return { type: rawType, wasDowngraded: false };
  const downgraded = _downgradeToSafe(rawType);
  logger.warn('plan.session.type.level_downgraded', {
    rawType,
    level: lvl,
    downgraded,
    ...ctx,
  });
  return { type: downgraded, wasDowngraded: true };
}

/**
 * Lógica compartilhada do fluxo de checkpoint, dividida em "propor" (gera a
 * análise + as semanas novas, SEM aplicar) e "aplicar" (faz o merge no plano).
 *
 * Usado por:
 *  - ProposeCheckpointUseCase (cron de domingo) → gera proposta pendente
 *  - ResolveProposalUseCase (aceite/recusa do usuário) → aplica/descarta
 */

/** Plano ainda em geração / falhou. 422 — user precisa aguardar. */
export class PlanNotReadyError extends AppError {
  constructor() {
    super('Plano ainda não está pronto.', 422, 'PLAN_NOT_READY');
  }
}

/** Checkpoint da semana já concluído (proposta aceita). 409. */
export class CheckpointAlreadyAppliedError extends AppError {
  public readonly weekNumber: number;
  public readonly completedAt?: string;
  constructor(weekNumber: number, completedAt?: string) {
    super(
      'Esse checkpoint já foi concluído nesta semana.',
      409,
      'CHECKPOINT_ALREADY_APPLIED',
    );
    this.weekNumber = weekNumber;
    this.completedAt = completedAt;
  }
}

/** Proposta já resolvida (aceita/recusada) ou inexistente. 409. */
export class ProposalAlreadyResolvedError extends AppError {
  constructor() {
    super(
      'Essa proposta já foi resolvida ou não está mais pendente.',
      409,
      'PROPOSAL_ALREADY_RESOLVED',
    );
  }
}

export interface CheckpointProposal {
  newWeeks: PlanWeek[];
  oldFollowingWeeks: PlanWeek[];
  autoAnalysis: string;
  coachExplanation: string;
}

/**
 * Roda a estratégia de análise e devolve as semanas seguintes ajustadas
 * (two-tier: 2 próximas em detalhe full, resto skeleton). NÃO persiste nada.
 */
export async function buildCheckpointProposal(
  deps: { runRepo: RunRepository; strategy: CheckpointAnalysisStrategy },
  plan: Plan,
  weekNumber: number,
  mergedInputs: CheckpointInput[],
  userId: string,
): Promise<CheckpointProposal> {
  const { runs, metrics } = await computeWeekData(deps.runRepo, plan, weekNumber, userId);

  // Snapshot biométrico 7d — sono, recovery, BPM repouso, HRV, passos.
  // Best-effort: se HealthKit não conectado / sync velha / erro, segue
  // sem biometrics (strategy lida com null). Sem isso o checkpoint
  // decidia overload/underload sem nenhum sinal fisiológico além das
  // próprias corridas.
  let biometricSummary: BiometricSummary | null = null;
  try {
    const { container } = await import('@shared/container');
    biometricSummary = await container.useCases.getBiometricSummary.execute(userId, 7);
  } catch (err) {
    logger.warn('checkpoint.biometrics_fetch_failed', {
      userId, weekNumber, err: err instanceof Error ? err.message : String(err),
    });
  }

  const analysisOut = await deps.strategy.analyze({
    plan,
    weekNumber,
    userInputs: mergedInputs,
    weekRuns: runs,
    weekMetrics: metrics,
    biometricSummary,
  });

  // `oldFollowingWeeks` reflete o estado VIGENTE (com revisões aplicadas),
  // não a base imutável. Cada revisão vê o plano "como está" hoje.
  const effective = effectivePlanWeeks(plan);
  const oldFollowingWeeks = effective.filter((w) => w.weekNumber > weekNumber);

  let newWeeks = analysisOut.newWeeks;
  if (newWeeks.length > 0) {
    const roteiroTpl = await getRoteiroTemplates();
    newWeeks = enrichTwoTier(newWeeks, oldFollowingWeeks, weekNumber, roteiroTpl);
  }

  return {
    newWeeks,
    oldFollowingWeeks,
    autoAnalysis: analysisOut.autoAnalysis,
    coachExplanation: analysisOut.coachExplanation,
  };
}

/**
 * Aplica as semanas novas (já enriquecidas) sobre o plano: preserva passado
 * (<= weekNumber) e substitui as futuras pelo snapshot proposto.
 */
export function mergeProposedWeeks(
  plan: Plan,
  weekNumber: number,
  newWeeks: PlanWeek[],
): PlanWeek[] {
  // Caller já passa plan.weeks como SNAPSHOT VIGENTE (effectivePlanWeeks)
  // pra cumulatividade. Aqui só aplicamos o diff: passado intacto, futuras
  // recebem replacement se o LLM mandou.
  if (newWeeks.length === 0) return plan.weeks;
  return plan.weeks.map((w) => {
    if (w.weekNumber <= weekNumber) return w;
    const replacement = newWeeks.find((nw) => nw.weekNumber === w.weekNumber);
    return replacement ?? w;
  });
}

/**
 * Segunda-feira (00:00 local) da semana civil que contém `d`. Em PT-BR a
 * semana é seg→dom. getDay() em domingo = 0 → recua 6 dias até a segunda
 * anterior; demais dias → recua (getDay()-1) dias.
 */
export function startOfCivilWeek(d: Date): Date {
  const out = new Date(d);
  const dow = out.getDay();
  const back = dow === 0 ? 6 : dow - 1;
  out.setDate(out.getDate() - back);
  out.setHours(0, 0, 0, 0);
  return out;
}

/**
 * Número da semana corrente do plano (1-based), alinhado à semana civil
 * (seg-dom). Semana 1 = semana civil que contém o startDate; a semana avança
 * toda segunda-feira, não 7 dias rolling desde a criação — caso contrário um
 * plano criado num domingo continuaria como "semana 1" até a próxima semana.
 */
export function currentWeekNumber(plan: Plan, now: Date = new Date()): number {
  const start = parseISO(plan.startDate ?? plan.createdAt.slice(0, 10)) ?? new Date(plan.createdAt);
  const diffWeeks = Math.floor(
    (startOfCivilWeek(now).getTime() - startOfCivilWeek(start).getTime()) /
      (7 * 86_400_000),
  );
  return Math.min(Math.max(diffWeeks + 1, 1), plan.weeksCount);
}

/**
 * Janela [start, end) da semana civil N (1-based) do plano. Semana 1 é a
 * semana civil (seg→dom) que contém o startDate; demais somam +7d.
 * Usado pra agregar runs/feedback da semana — alinhado com a fórmula de
 * `currentWeekNumber`. Antes a fórmula era rolling-7-day-from-startDate,
 * o que gerava janela errada quando startDate caía meio de semana civil.
 */
export function civilWeekRange(
  plan: Pick<Plan, 'startDate' | 'createdAt'>,
  weekNumber: number,
): { start: Date; end: Date } | null {
  const startISO = parseISO(plan.startDate ?? plan.createdAt.slice(0, 10));
  if (!startISO) return null;
  const startMonday = startOfCivilWeek(startISO);
  const start = new Date(startMonday.getTime() + (weekNumber - 1) * 7 * 86_400_000);
  const end = new Date(start.getTime() + 7 * 86_400_000);
  return { start, end };
}

export async function computeWeekData(
  runRepo: RunRepository,
  plan: Plan,
  weekNumber: number,
  userId: string,
): Promise<{ runs: CheckpointWeekRun[]; metrics: CheckpointWeekMetrics }> {
  const range = civilWeekRange(plan, weekNumber);
  if (!range) {
    return { runs: [], metrics: emptyMetrics(plan, weekNumber) };
  }
  const { start: weekStart, end: weekEnd } = range;
  // findByUser (ordenado por createdAt desc) + filtro em memória — evita o
  // composite index exigido por findByDateRange (status + createdAt).
  const recentRuns = await runRepo.findByUser(userId, 50);
  const completed = recentRuns.runs.filter((r: Run) => {
    if (r.status !== 'completed') return false;
    const t = new Date(r.createdAt).getTime();
    return t >= weekStart.getTime() && t < weekEnd.getTime();
  });

  const runs: CheckpointWeekRun[] = completed.map((r) => ({
    date: new Date(r.createdAt).toISOString().slice(0, 10),
    distanceKm: r.distanceM / 1000,
    durationS: r.durationS,
    avgPace: r.avgPace ?? undefined,
    avgBpm: r.avgBpm ?? undefined,
    maxBpm: r.maxBpm ?? undefined,
    planSessionId: r.planSessionId ?? null,
    userFeedback: r.userFeedback?.length ? r.userFeedback : undefined,
  }));

  const week = effectivePlanWeeks(plan).find((w) => w.weekNumber === weekNumber);
  const plannedSessions = week?.sessions.length ?? 0;
  const plannedDistanceKm = week
    ? week.sessions.reduce((s, x) => s + x.distanceKm, 0)
    : 0;
  const actualDistanceKm = runs.reduce((s, r) => s + r.distanceKm, 0);
  const completionRate = plannedSessions === 0 ? 0 : Math.min(1, runs.length / plannedSessions);
  const bpmValues = runs.map((r) => r.avgBpm).filter((b): b is number => !!b);
  const avgBpm = bpmValues.length
    ? Math.round(bpmValues.reduce((a, b) => a + b, 0) / bpmValues.length)
    : undefined;
  // Pace médio = duração TOTAL / distância TOTAL (média ponderada pelo
  // volume), igual ao history page. Antes era média aritmética simples
  // das paces de cada run, que infla o resultado quando há mix de runs
  // curtas lentas e longas rápidas (uma run de 1km em 10min pesa igual
  // a uma de 8km em 50min na conta de média simples).
  const avgPaceMinPerKm = weightedPace(runs);

  // Split planejado vs free. Sem essa separação o coach não distingue
  // "fez o plano" de "fez free runs que compensam o déficit".
  const plannedRuns = runs.filter((r) => r.planSessionId);
  const freeRuns = runs.filter((r) => !r.planSessionId);
  const plannedRunsDistanceKm = plannedRuns.reduce((s, r) => s + r.distanceKm, 0);
  const freeRunsDistanceKm = freeRuns.reduce((s, r) => s + r.distanceKm, 0);
  const plannedRunsAvgPaceMinPerKm = weightedPace(plannedRuns);
  const freeRunsAvgPaceMinPerKm = weightedPace(freeRuns);

  return {
    runs,
    metrics: {
      plannedSessions,
      completedRuns: runs.length,
      plannedDistanceKm,
      actualDistanceKm,
      plannedRunsDistanceKm,
      freeRunsDistanceKm,
      completionRate,
      avgBpm,
      avgPaceMinPerKm,
      plannedRunsAvgPaceMinPerKm,
      freeRunsAvgPaceMinPerKm,
    },
  };
}

/**
 * Two-tier: 2 próximas semanas viram 'full' (roteiro km-a-km + nutrição); o
 * resto segue 'skeleton'. Preserva metadados de bloco/narrativa e IDs.
 */
export function enrichTwoTier(
  newWeeks: PlanWeek[],
  oldFollowingWeeks: PlanWeek[],
  weekNumber: number,
  roteiroTpl: RoteiroTemplates,
): PlanWeek[] {
  const detailNums = oldFollowingWeeks
    .map((w) => w.weekNumber)
    .filter((n) => n > weekNumber)
    .sort((a, b) => a - b)
    .slice(0, 2);

  return newWeeks.map((w) => {
    const old = oldFollowingWeeks.find((o) => o.weekNumber === w.weekNumber);
    const isFull = detailNums.includes(w.weekNumber);
    const sessions: PlanSession[] = (w.sessions ?? []).map((s) => {
      const id = s.id && s.id.length > 0 ? s.id : uuid();
      const rawDistance = Number(Number(s.distanceKm).toFixed(1));
      const sanitized = sanitizeSessionType(s.type, rawDistance, {
        weekNumber: w.weekNumber,
        dayOfWeek: s.dayOfWeek,
      });
      // Resolve o tipo "efetivo": se distância não acomoda a fórmula do
      // tipo solicitado (ex: Tiros 2.5km), rebatiza pra Easy Run pra UI
      // e roteiro ficarem coerentes.
      const distanceKm = sanitized.distanceKm;
      const type = resolveEffectiveSessionType(sanitized.type, distanceKm);
      if (isFull) {
        const base = {
          id,
          dayOfWeek: s.dayOfWeek,
          type,
          distanceKm,
          targetPace: s.targetPace,
          durationMin: s.durationMin,
          hydrationLiters: s.hydrationLiters,
          nutritionPre: s.nutritionPre,
          nutritionPost: s.nutritionPost,
          notes: s.notes ?? '',
        } satisfies Omit<PlanSession, 'executionSegments'>;
        // SEMPRE regenera via builder determinístico. Antes preservávamos
        // segments quando o LLM mandava, mas observamos sessão "Tiros"
        // ganhando roteiro de Easy Run quando o LLM gerava as duas coisas
        // desalinhadas (wk3 dow3 do plano do user em 2026-06-08). O builder
        // usa templates curados (Dossiê 4) e cobre todos os tipos, então
        // não há vantagem em confiar no LLM aqui — só vetor de regressão.
        const segs = buildExecutionSegments(base, roteiroTpl);
        return { ...base, executionSegments: segs } satisfies PlanSession;
      }
      return {
        id,
        dayOfWeek: s.dayOfWeek,
        type,
        distanceKm,
        targetPace: s.targetPace,
        notes: s.notes ?? '',
      } satisfies PlanSession;
    });

    return {
      weekNumber: w.weekNumber,
      sessions,
      detailLevel: isFull ? ('full' as const) : ('skeleton' as const),
      projectedLoadKm: Number(sessions.reduce((a, s) => a + s.distanceKm, 0).toFixed(1)),
      blockName: w.blockName ?? old?.blockName,
      objective: w.objective ?? old?.objective,
      targets: w.targets ?? old?.targets,
      narrative: w.narrative ?? old?.narrative,
      focus: w.focus ?? old?.focus,
      restDayTips: isFull ? (w.restDayTips ?? old?.restDayTips) : undefined,
    } satisfies PlanWeek;
  });
}

export function emptyMetrics(plan: Plan, weekNumber: number): CheckpointWeekMetrics {
  const week = effectivePlanWeeks(plan).find((w) => w.weekNumber === weekNumber);
  return {
    plannedSessions: week?.sessions.length ?? 0,
    completedRuns: 0,
    plannedDistanceKm: week?.sessions.reduce((s, x) => s + x.distanceKm, 0) ?? 0,
    actualDistanceKm: 0,
    plannedRunsDistanceKm: 0,
    freeRunsDistanceKm: 0,
    completionRate: 0,
  };
}

export function mergeInputs(
  existing: CheckpointInput[],
  extra: CheckpointInput[],
): CheckpointInput[] {
  const all = [...existing, ...extra];
  const seen = new Set<string>();
  return all.filter((i) => {
    const k = `${i.type}|${i.note ?? ''}`;
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
}

export function deriveRequestType(inputs: CheckpointInput[]): PlanRevision['requestType'] {
  if (inputs.length === 0) return 'other';
  if (inputs.some((i) => i.type === 'pain')) return 'pain_or_discomfort';
  if (inputs.some((i) => i.type === 'load_up' || i.type === 'great_week')) return 'more_load';
  if (inputs.some((i) => i.type === 'load_down' || i.type === 'low_energy' || i.type === 'sleep_bad'))
    return 'less_load';
  if (inputs.some((i) => i.type === 'schedule_conflict')) return 'less_days';
  return 'other';
}

function parseISO(s: string): Date | null {
  const d = new Date(`${s}T00:00:00`);
  return isNaN(d.getTime()) ? null : d;
}

/** Resumo curto (1-2 frases) pra renderizar em _RevisionsSection. */
/** Apenas semanas presentes em AMBOS (mesmo weekNumber). Sem essa
 *  intersecção, comparar `oldFollowingWeeks` (todas as seguintes) com
 *  `newWeeks` (só current+1 e +2 desde Fix 7) gera delta apples-to-oranges
 *  (ex: -236km quando na verdade só 2 semanas mudaram suavemente). */
function intersectByWeekNumber(
  oldWeeks: PlanWeek[],
  newWeeks: PlanWeek[],
): { oldKm: number; newKm: number; oldCount: number; newCount: number } {
  const newByNumber = new Map(newWeeks.map((w) => [w.weekNumber, w]));
  let oldKm = 0;
  let newKm = 0;
  let oldCount = 0;
  let newCount = 0;
  for (const o of oldWeeks) {
    const n = newByNumber.get(o.weekNumber);
    if (!n) continue;
    oldKm += o.sessions.reduce((a, x) => a + (x.distanceKm ?? 0), 0);
    newKm += n.sessions.reduce((a, x) => a + (x.distanceKm ?? 0), 0);
    oldCount += o.sessions.length;
    newCount += n.sessions.length;
  }
  return { oldKm, newKm, oldCount, newCount };
}

export function buildLogSummary(
  inputs: CheckpointInput[],
  oldWeeks: PlanWeek[],
  newWeeks: PlanWeek[],
): string {
  const { oldKm, newKm } = intersectByWeekNumber(oldWeeks, newWeeks);
  const delta = newKm - oldKm;
  const deltaStr =
    Math.abs(delta) < 0.5
      ? 'volume mantido'
      : delta > 0
        ? `volume +${delta.toFixed(1)}km`
        : `volume ${delta.toFixed(1)}km`;
  const weeksAdjusted = newWeeks.length;
  const triggerLabels = inputs.length
    ? inputs.map((i) => i.type).slice(0, 3).join(', ')
    : 'sem inputs (análise automática)';
  return `Revisão semanal — ${triggerLabels}. ${deltaStr} nas ${weeksAdjusted} próximas semanas.`;
}

export function buildChangesSnapshot(
  oldWeeks: PlanWeek[],
  newWeeks: PlanWeek[],
): PlanRevisionLog['changes'] {
  const { oldKm, newKm, oldCount, newCount } = intersectByWeekNumber(oldWeeks, newWeeks);
  const volumeDelta = +(newKm - oldKm).toFixed(1);
  const intensityShift: 'increased' | 'decreased' | 'unchanged' =
    volumeDelta > 0.5 ? 'increased' : volumeDelta < -0.5 ? 'decreased' : 'unchanged';
  return {
    sessionsAdjusted: Math.abs(newCount - oldCount),
    volumeDelta,
    intensityShift,
  };
}
