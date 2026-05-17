import { v4 as uuid } from 'uuid';
import { Plan, PlanWeek } from '../domain/plan.entity';
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
import { logger } from '@shared/logger/logger';

export class CheckpointError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly meta?: Record<string, unknown>,
  ) {
    super(message);
    this.name = 'CheckpointError';
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
      throw new CheckpointError('Plano não encontrado.', 'PLAN_NOT_FOUND');
    }
    if (plan.status !== 'ready') {
      throw new CheckpointError(
        'Plano ainda não está pronto.',
        'PLAN_NOT_READY',
      );
    }

    const cp = await this.checkpointRepo.findByWeek(planId, weekNumber, userId);
    if (!cp) {
      throw new CheckpointError(
        'Checkpoint não existe pra essa semana.',
        'CHECKPOINT_NOT_FOUND',
        { weekNumber },
      );
    }
    if (cp.status === 'completed') {
      throw new CheckpointError(
        'Esse checkpoint já foi aplicado. Próximo ajuste disponível no checkpoint da semana seguinte.',
        'CHECKPOINT_ALREADY_APPLIED',
        { weekNumber, completedAt: cp.completedAt },
      );
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
      await this.planRepo.update(planId, userId, {
        weeks: newPlanWeeks,
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
    const runsRaw = await this.runRepo.findByDateRange(userId, weekStart, weekEnd);
    const completed = runsRaw.filter((r: Run) => r.status === 'completed');

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
