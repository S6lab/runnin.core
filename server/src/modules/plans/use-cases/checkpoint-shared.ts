import { v4 as uuid } from 'uuid';
import {
  Plan,
  PlanRevision as PlanRevisionLog,
  PlanSession,
  PlanWeek,
} from '../domain/plan.entity';
import { buildExecutionSegments } from './build-execution-segments';
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

  const analysisOut = await deps.strategy.analyze({
    plan,
    weekNumber,
    userInputs: mergedInputs,
    weekRuns: runs,
    weekMetrics: metrics,
  });

  const oldFollowingWeeks = plan.weeks.filter((w) => w.weekNumber > weekNumber);

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
function startOfCivilWeek(d: Date): Date {
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

export async function computeWeekData(
  runRepo: RunRepository,
  plan: Plan,
  weekNumber: number,
  userId: string,
): Promise<{ runs: CheckpointWeekRun[]; metrics: CheckpointWeekMetrics }> {
  const start = parseISO(plan.startDate ?? plan.createdAt.slice(0, 10));
  if (!start) {
    return { runs: [], metrics: emptyMetrics(plan, weekNumber) };
  }
  const weekStart = new Date(start.getTime() + (weekNumber - 1) * 7 * 86_400_000);
  const weekEnd = new Date(weekStart.getTime() + 7 * 86_400_000);
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
    userFeedback: r.userFeedback?.length ? r.userFeedback : undefined,
  }));

  const week = plan.weeks.find((w) => w.weekNumber === weekNumber);
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
  const avgPaceMinPerKm = runs.length
    ? runs.reduce((s, r) => s + r.durationS / 60 / r.distanceKm, 0) / runs.length
    : undefined;

  return {
    runs,
    metrics: {
      plannedSessions,
      completedRuns: runs.length,
      plannedDistanceKm,
      actualDistanceKm,
      completionRate,
      avgBpm,
      avgPaceMinPerKm,
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
      const type = sanitized.type;
      const distanceKm = sanitized.distanceKm;
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
        const segs =
          (s.executionSegments?.length ?? 0) > 0
            ? s.executionSegments
            : buildExecutionSegments(base, roteiroTpl);
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
  const week = plan.weeks.find((w) => w.weekNumber === weekNumber);
  return {
    plannedSessions: week?.sessions.length ?? 0,
    completedRuns: 0,
    plannedDistanceKm: week?.sessions.reduce((s, x) => s + x.distanceKm, 0) ?? 0,
    actualDistanceKm: 0,
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
export function buildLogSummary(
  inputs: CheckpointInput[],
  oldWeeks: PlanWeek[],
  newWeeks: PlanWeek[],
): string {
  const oldKm = oldWeeks.reduce((s, w) => s + w.sessions.reduce((a, x) => a + x.distanceKm, 0), 0);
  const newKm = newWeeks.reduce((s, w) => s + w.sessions.reduce((a, x) => a + x.distanceKm, 0), 0);
  const delta = newKm - oldKm;
  const deltaStr =
    Math.abs(delta) < 0.5
      ? 'volume mantido'
      : delta > 0
        ? `volume +${delta.toFixed(1)}km`
        : `volume ${delta.toFixed(1)}km`;
  const triggerLabels = inputs.length
    ? inputs.map((i) => i.type).slice(0, 3).join(', ')
    : 'sem inputs (análise automática)';
  return `Revisão semanal — ${triggerLabels}. ${deltaStr} nas semanas seguintes.`;
}

export function buildChangesSnapshot(
  oldWeeks: PlanWeek[],
  newWeeks: PlanWeek[],
): PlanRevisionLog['changes'] {
  const oldKm = oldWeeks.reduce((s, w) => s + w.sessions.reduce((a, x) => a + x.distanceKm, 0), 0);
  const newKm = newWeeks.reduce((s, w) => s + w.sessions.reduce((a, x) => a + x.distanceKm, 0), 0);
  const volumeDelta = +(newKm - oldKm).toFixed(1);
  const oldCount = oldWeeks.reduce((s, w) => s + w.sessions.length, 0);
  const newCount = newWeeks.reduce((s, w) => s + w.sessions.length, 0);
  const intensityShift: 'increased' | 'decreased' | 'unchanged' =
    volumeDelta > 0.5 ? 'increased' : volumeDelta < -0.5 ? 'decreased' : 'unchanged';
  return {
    sessionsAdjusted: Math.abs(newCount - oldCount),
    volumeDelta,
    intensityShift,
  };
}
