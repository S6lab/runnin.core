import { v4 as uuid } from 'uuid';
import { Plan, PlanRevision as PlanRevisionLog, PlanWeek } from '../domain/plan.entity';
import { PlanRepository } from '../domain/plan.repository';
import { PlanRevision } from '../domain/plan-revision.entity';
import { PlanRevisionRepository } from '../domain/plan-revision.repository';
import {
  CheckpointInput,
  PlanCheckpoint,
} from '../domain/plan-checkpoint.entity';
import { PlanCheckpointRepository } from '../domain/plan-checkpoint.repository';
import { RunRepository } from '@modules/runs/domain/run.repository';
import { Run } from '@modules/runs/domain/run.entity';
import {
  CheckpointAnalysisStrategy,
  CheckpointWeekMetrics,
  CheckpointWeekRun,
} from './checkpoint-analysis.strategy';
import { AppError, NotFoundError } from '@shared/errors/app-error';
import { logger } from '@shared/logger/logger';

/**
 * Erro específico: checkpoint dessa semana já foi aplicado. 409.
 * Carrega `completedAt` no body pra UI mostrar quando o user usou.
 */
export class CheckpointAlreadyAppliedError extends AppError {
  public readonly weekNumber: number;
  public readonly completedAt?: string;
  constructor(weekNumber: number, completedAt?: string) {
    super(
      'Esse checkpoint já foi aplicado. Próximo ajuste disponível no checkpoint da semana seguinte.',
      409,
      'CHECKPOINT_ALREADY_APPLIED',
    );
    this.weekNumber = weekNumber;
    this.completedAt = completedAt;
  }
}

/** Plano ainda em geração / falhou. 422 — user precisa aguardar. */
export class PlanNotReadyError extends AppError {
  constructor() {
    super('Plano ainda não está pronto.', 422, 'PLAN_NOT_READY');
  }
}

/**
 * Apply: roda a estratégia de análise, aplica o ajuste no plano e
 * grava PlanRevision + atualiza PlanCheckpoint pra `completed`.
 *
 * Garante regra de negócio "1x por semana": se o checkpoint da semana
 * já está `completed`, rejeita (CHECKPOINT_ALREADY_APPLIED). User
 * pode submeter inputs e re-abrir, mas só 1 apply por semana.
 *
 * Mantém o passado intocado: só semanas weekNumber+1..N podem mudar.
 */
export class ApplyCheckpointUseCase {
  constructor(
    private readonly planRepo: PlanRepository,
    private readonly checkpointRepo: PlanCheckpointRepository,
    private readonly revisionRepo: PlanRevisionRepository,
    private readonly runRepo: RunRepository,
    private readonly strategy: CheckpointAnalysisStrategy,
  ) {}

  async execute(
    userId: string,
    planId: string,
    weekNumber: number,
    extraInputs: CheckpointInput[] = [],
  ): Promise<{
    checkpoint: PlanCheckpoint;
    revision?: PlanRevision;
    plan: Plan;
  }> {
    const plan = await this.planRepo.findById(planId, userId);
    if (!plan) {
      throw new NotFoundError('Plan');
    }
    if (plan.status !== 'ready') {
      throw new PlanNotReadyError();
    }

    const cp = await this.checkpointRepo.findByWeek(planId, weekNumber, userId);
    if (!cp) {
      throw new NotFoundError('Checkpoint');
    }
    if (cp.status === 'completed') {
      throw new CheckpointAlreadyAppliedError(weekNumber, cp.completedAt);
    }

    const mergedInputs = mergeInputs(cp.userInputs ?? [], extraInputs);

    const { runs, metrics } = await this._computeWeekData(plan, weekNumber, userId);

    const analysisOut = await this.strategy.analyze({
      plan,
      weekNumber,
      userInputs: mergedInputs,
      weekRuns: runs,
      weekMetrics: metrics,
    });

    // Snapshot anterior (só semanas que vão mudar) pro PlanRevision.
    const oldFollowingWeeks = plan.weeks.filter((w) => w.weekNumber > weekNumber);

    let newPlanWeeks = plan.weeks;
    if (analysisOut.newWeeks.length > 0) {
      newPlanWeeks = plan.weeks.map((w) => {
        if (w.weekNumber <= weekNumber) return w;
        const replacement = analysisOut.newWeeks.find(
          (nw) => nw.weekNumber === w.weekNumber,
        );
        return replacement ?? w;
      });
    }

    const now = new Date().toISOString();

    let revision: PlanRevision | undefined;
    if (analysisOut.newWeeks.length > 0) {
      revision = {
        id: uuid(),
        planId,
        userId,
        weekIndex: weekNumber,
        requestType: deriveRequestType(mergedInputs),
        freeText: mergedInputs.find((i) => i.note)?.note,
        oldWeeksSnapshot: oldFollowingWeeks,
        newWeeksSnapshot: analysisOut.newWeeks,
        coachExplanation: analysisOut.coachExplanation,
        status: 'applied',
        createdAt: now,
        appliedAt: now,
      };
      await this.revisionRepo.save(revision);

      // Adiciona entrada no log embutido `plan.revisions[]` pra renderizar
      // no PlanDetailPage > _RevisionsSection. O snapshot completo fica no
      // collection PlanRevision (acessível via /plans/:id/revisions).
      const logEntry: PlanRevisionLog = {
        weekNumber,
        revisedAt: now,
        trigger: 'checkpoint',
        summary: buildLogSummary(mergedInputs, oldFollowingWeeks, analysisOut.newWeeks),
        details: analysisOut.coachExplanation,
        changes: buildChangesSnapshot(oldFollowingWeeks, analysisOut.newWeeks),
      };
      const updatedRevisions = [...(plan.revisions ?? []), logEntry];

      await this.planRepo.update(planId, userId, {
        weeks: newPlanWeeks,
        revisions: updatedRevisions,
        updatedAt: now,
      });
    } else {
      logger.info('checkpoint.apply.no_changes', {
        planId,
        weekNumber,
        inputsCount: mergedInputs.length,
      });
    }

    await this.checkpointRepo.update(planId, weekNumber, userId, {
      status: 'completed',
      userInputs: mergedInputs,
      autoAnalysis: analysisOut.autoAnalysis,
      resultRevisionId: revision?.id,
      completedAt: now,
    });

    const refreshed: PlanCheckpoint = {
      ...cp,
      status: 'completed',
      userInputs: mergedInputs,
      autoAnalysis: analysisOut.autoAnalysis,
      resultRevisionId: revision?.id,
      completedAt: now,
    };
    const refreshedPlan: Plan = {
      ...plan,
      weeks: newPlanWeeks,
      updatedAt: now,
    };
    return { checkpoint: refreshed, revision, plan: refreshedPlan };
  }

  private async _computeWeekData(
    plan: Plan,
    weekNumber: number,
    userId: string,
  ): Promise<{ runs: CheckpointWeekRun[]; metrics: CheckpointWeekMetrics }> {
    const start = parseISO(plan.startDate ?? plan.createdAt.slice(0, 10));
    if (!start) {
      return {
        runs: [],
        metrics: emptyMetrics(plan, weekNumber),
      };
    }
    const weekStart = new Date(start.getTime() + (weekNumber - 1) * 7 * 86_400_000);
    const weekEnd = new Date(weekStart.getTime() + 7 * 86_400_000);
    // Não usamos findByDateRange porque ele exige composite index
    // (status + createdAt). findByUser retorna em ordem de createdAt
    // desc; filtramos por data + status em memória — semanas têm poucos
    // runs (<10), payload pequeno mesmo no limite alto.
    const recentRuns = await this.runRepo.findByUser(userId, 50);
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
    }));

    const week = plan.weeks.find((w) => w.weekNumber === weekNumber);
    const plannedSessions = week?.sessions.length ?? 0;
    const plannedDistanceKm = week
      ? week.sessions.reduce((s, x) => s + x.distanceKm, 0)
      : 0;
    const actualDistanceKm = runs.reduce((s, r) => s + r.distanceKm, 0);
    const completionRate = plannedSessions === 0
      ? 0
      : Math.min(1, runs.length / plannedSessions);
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
}

function emptyMetrics(plan: Plan, weekNumber: number): CheckpointWeekMetrics {
  const week = plan.weeks.find((w) => w.weekNumber === weekNumber);
  return {
    plannedSessions: week?.sessions.length ?? 0,
    completedRuns: 0,
    plannedDistanceKm: week?.sessions.reduce((s, x) => s + x.distanceKm, 0) ?? 0,
    actualDistanceKm: 0,
    completionRate: 0,
  };
}

function mergeInputs(
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

function deriveRequestType(
  inputs: CheckpointInput[],
): PlanRevision['requestType'] {
  if (inputs.length === 0) return 'other';
  if (inputs.some((i) => i.type === 'pain')) return 'pain_or_discomfort';
  if (inputs.some((i) => i.type === 'load_up' || i.type === 'great_week'))
    return 'more_load';
  if (inputs.some((i) => i.type === 'load_down' || i.type === 'low_energy' || i.type === 'sleep_bad'))
    return 'less_load';
  if (inputs.some((i) => i.type === 'schedule_conflict'))
    return 'less_days';
  return 'other';
}

function parseISO(s: string): Date | null {
  const d = new Date(`${s}T00:00:00`);
  return isNaN(d.getTime()) ? null : d;
}

/** Resumo curto (1-2 frases) pra renderizar em _RevisionsSection. */
function buildLogSummary(
  inputs: CheckpointInput[],
  oldWeeks: PlanWeek[],
  newWeeks: PlanWeek[],
): string {
  const oldKm = oldWeeks.reduce(
    (s, w) => s + w.sessions.reduce((a, x) => a + x.distanceKm, 0),
    0,
  );
  const newKm = newWeeks.reduce(
    (s, w) => s + w.sessions.reduce((a, x) => a + x.distanceKm, 0),
    0,
  );
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
  return `Checkpoint aplicado — ${triggerLabels}. ${deltaStr} nas semanas seguintes.`;
}

function buildChangesSnapshot(
  oldWeeks: PlanWeek[],
  newWeeks: PlanWeek[],
): PlanRevisionLog['changes'] {
  const oldKm = oldWeeks.reduce(
    (s, w) => s + w.sessions.reduce((a, x) => a + x.distanceKm, 0),
    0,
  );
  const newKm = newWeeks.reduce(
    (s, w) => s + w.sessions.reduce((a, x) => a + x.distanceKm, 0),
    0,
  );
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
