import { v4 as uuid } from 'uuid';
import { z } from 'zod';
import { PlanRepository } from '../domain/plan.repository';
import { PlanRevisionRepository } from '../domain/plan-revision.repository';
import { UserRepository } from '@modules/users/domain/user.repository';
import { PlanRevision, PlanRevisionRequestType, PlanRevisionStatus } from '../domain/plan-revision.entity';
import { UserProfile } from '@modules/users/domain/user.entity';
import { Plan, PlanWeek, effectivePlanWeeks } from '../domain/plan.entity';
import { logger } from '@shared/logger/logger';
import { S6AiClient, S6RevisePlanResponse } from '@shared/infra/s6ai/s6ai.client';
import { enforceRevisionInvariants } from './enforce-race-week-structure';
import { currentWeekNumber } from './checkpoint-shared';

export class QuotaExhaustedError extends Error {
  public readonly quota: { usedThisWeek: number; max: number; resetAt: string };

  constructor(usedThisWeek: number, max: number, resetAt: string) {
    super('Quota exhausted');
    this.name = 'QuotaExhaustedError';
    this.quota = { usedThisWeek, max, resetAt };
  }
}

export const RequestRevisionSchema = z.object({
  type: z.enum([
    'more_load',
    'less_load',
    'more_days',
    'less_days',
    'more_tempo',
    'more_resistance',
    'more_intervals',
    'change_days',
    'pain_or_discomfort',
    'other',
  ] as [string, ...string[]]),
  subOption: z.string().optional(),
  freeText: z.string().optional(),
});

export type RequestRevisionInput = z.infer<typeof RequestRevisionSchema>;

export class RequestRevisionUseCase {
  // Prompt + LLM + parse/repair vivem no s6-ai. Aqui: quota, merge,
  // invariantes de race week e persistência.
  private s6ai = new S6AiClient();

  constructor(
    private readonly plans: PlanRepository,
    private readonly revisions: PlanRevisionRepository,
    private readonly users: UserRepository,
  ) {}

  async execute(
    userId: string,
    planId: string,
    input: RequestRevisionInput,
    opts: { bypassQuota?: boolean } = {},
  ): Promise<{
    revision: PlanRevision;
    updatedPlan: Plan;
  }> {
    const plan = await this.plans.findById(planId, userId);
    if (!plan) {
      throw new Error(`Plan not found: ${planId}`);
    }

    const profile = await this.users.findById(userId);
    if (!profile) {
      throw new Error(`User not found: ${userId}`);
    }

    const now = new Date().toISOString();
    let quota = profile.planRevisions ?? { usedThisWeek: 0, max: 1, resetAt: now };

    if (quota.resetAt && new Date(quota.resetAt) < new Date()) {
      quota = { usedThisWeek: 0, max: quota.max ?? 1, resetAt: now };
    }

    // bypassQuota usado por adaptações automáticas pós-run / missed day —
    // não consomem a cota mensal do usuário.
    if (!opts.bypassQuota && quota.usedThisWeek >= quota.max) {
      throw new QuotaExhaustedError(quota.usedThisWeek, quota.max, quota.resetAt);
    }

    const currentWeekIndex = this._getCurrentWeekIndex(plan);
    // Estado VIGENTE: respeita revisões anteriores cumulativas.
    const effectiveWeeks = effectivePlanWeeks(plan);
    const oldWeeksSnapshot = [...effectiveWeeks];

    const futureWeeks = effectiveWeeks.slice(currentWeekIndex);

    let coachExplanation: string;
    let newWeeks: typeof plan.weeks;

    try {
      const s6 = await this.s6ai.revisePlan({
        userId,
        profile,
        plan: {
          goal: plan.goal,
          level: plan.level,
          weeksCount: plan.weeksCount,
          weeks: futureWeeks,
          raceDate: plan.raceDate ?? null,
          raceDayOfWeek: plan.raceDayOfWeek ?? null,
        },
        revision: {
          type: input.type,
          subOption: input.subOption,
          freeText: input.freeText,
        },
        currentWeekNumber: currentWeekIndex + 1, // 1-based pro prompt
      });

      coachExplanation = s6.coachExplanation;
      // Merge sobre o snapshot VIGENTE (cumulativo). plan.weeks é a BASE
      // imutável; comparamos contra ela só pra invariantes estruturais.
      const merged = this._mergeWeeks(effectiveWeeks, s6.newWeeks, currentWeekIndex);
      const enforced = enforceRevisionInvariants(merged, {
        plan,
        originalWeeks: plan.weeks,
        currentWeekNumber: currentWeekIndex + 1,
      });
      newWeeks = enforced.weeks;
      logger.info('plan.revision.generated', {
        planId,
        version: s6.meta.promptVersion,
        source: s6.meta.promptSource,
      });
    } catch (err) {
      logger.error('plan.revision.llm_failed', {
        planId,
        err: err instanceof Error ? err.message : String(err),
      });
      throw new Error('Failed to generate revision: ' + (err instanceof Error ? err.message : String(err)));
    }

    // ARQUITETURA: plan.weeks (BASE) é IMUTÁVEL. Revisões — manuais ou auto —
    // só tocam em `adjustedWeeks`, que é o snapshot vigente lido por
    // `effectivePlanWeeks` em todas as telas de treino atual.
    const updatedPlan = {
      ...plan,
      adjustedWeeks: newWeeks,
      updatedAt: new Date().toISOString(),
    };

    await this.plans.update(plan.id, userId, {
      adjustedWeeks: updatedPlan.adjustedWeeks,
      updatedAt: updatedPlan.updatedAt,
    });

    // ID determinístico por (plano, semana) — mesma estratégia do
    // apply-weekly-revision. Garante 1 doc por (plano, semana) na
    // collection planRevisions, sem importar quantas vezes o user (ou
    // adaptação automática pós-run) dispare. Antes era uuid() + save(),
    // que duplicava docs sob retry/auto-trigger; cleanup feito em
    // server/scripts/dedupe-plan-revisions.js.
    // weekNumber é 1-based (igual ao apply-weekly-revision) pra que ambos
    // os caminhos produzam o MESMO id pra mesma semana civil.
    const revisionId = `${plan.id}_w${currentWeekIndex + 1}`;
    const appliedAt = new Date().toISOString();
    const createdAt = appliedAt;
    const revision: PlanRevision = {
      id: revisionId,
      planId: plan.id,
      userId,
      weekIndex: currentWeekIndex,
      requestType: input.type as PlanRevisionRequestType,
      subOption: input.subOption,
      freeText: input.freeText,
      oldWeeksSnapshot,
      newWeeksSnapshot: updatedPlan.adjustedWeeks.slice(currentWeekIndex),
      coachExplanation,
      status: 'applied',
      createdAt,
      appliedAt,
    };

    // `save()` faz `.set(id)` — idempotente por id. 2 calls com mesmo
    // (planId, weekIndex) sobrescrevem o mesmo doc em vez de duplicar.
    await this.revisions.save(revision);

    // Adaptações automáticas não consomem cota do usuário.
    if (!opts.bypassQuota) {
      const newQuota = {
        usedThisWeek: quota.usedThisWeek + 1,
        max: quota.max,
        resetAt: quota.resetAt,
      };

      await this.users.upsert({
        ...profile,
        planRevisions: newQuota,
        updatedAt: now,
      });
    }

    return { revision, updatedPlan };
  }

  /** Semana corrente 0-based via helper CANÔNICO (semana civil ancorada
   *  em startDate — checkpoint-shared). A fórmula antiga (ceil rolling-7d
   *  desde createdAt) mirava semana errada pra plano que não começa na
   *  segunda: a revisão manual recortava futureWeeks fora de fase com o
   *  cron de domingo. */
  private _getCurrentWeekIndex(plan: Plan): number {
    return currentWeekNumber(plan) - 1;
  }

  private _mergeWeeks(
    originalWeeks: Plan['weeks'],
    newWeeks: S6RevisePlanResponse['newWeeks'],
    currentWeekIndex: number,
  ): Plan['weeks'] {
    const oldPrefix = originalWeeks.slice(0, currentWeekIndex);
    const hydrated: PlanWeek[] = newWeeks.map((w) => ({
      ...w,
      sessions: w.sessions.map((s) => ({ ...s, id: uuid() })),
    }));
    return [...oldPrefix, ...hydrated];
  }
}
