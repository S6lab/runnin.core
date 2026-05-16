import { v4 as uuid } from 'uuid';
import { z } from 'zod';
import { getAsyncLLM } from '@shared/infra/llm/llm.factory';
import { PlanRepository } from '../domain/plan.repository';
import { PlanRevisionRepository } from '../domain/plan-revision.repository';
import { UserRepository } from '@modules/users/domain/user.repository';
import { PlanRevision, PlanRevisionRequestType, PlanRevisionStatus } from '../domain/plan-revision.entity';
import { UserProfile } from '@modules/users/domain/user.entity';
import { Plan, PlanWeek } from '../domain/plan.entity';
import { logger } from '@shared/logger/logger';
import { formatRunningKnowledgeContext } from '@shared/knowledge/running/running-knowledge';

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

const PlanSessionSchema = z.object({
  dayOfWeek: z.number().int().min(1).max(7),
  type: z.string().min(1),
  distanceKm: z.number().positive(),
  targetPace: z.string().min(1).optional(),
  notes: z.string(),
});

const PlanWeekSchema = z.object({
  weekNumber: z.number().int().positive(),
  sessions: z.array(PlanSessionSchema),
  focus: z.string().optional(),
  narrative: z.string().optional(),
});

const RevisionResponseSchema = z.object({
  coachExplanation: z.string().min(20).max(400),
  newWeeks: z.array(PlanWeekSchema).min(1),
});

export class RequestRevisionUseCase {
  private llm = getAsyncLLM();

  constructor(
    private readonly plans: PlanRepository,
    private readonly revisions: PlanRevisionRepository,
    private readonly users: UserRepository,
  ) {}

  async execute(userId: string, planId: string, input: RequestRevisionInput): Promise<{
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

    if (quota.usedThisWeek >= quota.max) {
      throw new QuotaExhaustedError(quota.usedThisWeek, quota.max, quota.resetAt);
    }

    const currentWeekIndex = this._getCurrentWeekIndex(plan);
    const oldWeeksSnapshot = [...plan.weeks];

    const knowledgeContext = await formatRunningKnowledgeContext(
      `${plan.goal} ${plan.level} corrida plano de ${plan.weeksCount} semanas`,
      5,
    );

    const prompt = this._buildLLMPrompt(plan, currentWeekIndex, input, profile, knowledgeContext);

    let coachExplanation: string;
    let newWeeks: typeof plan.weeks;

    try {
      const raw = await this.llm.generate(prompt, {
        systemPrompt: this._getSystemPrompt(),
        maxTokens: 4000,
      });

      const parsed = this._parseRevisionResponse(raw);
      coachExplanation = parsed.coachExplanation;
      newWeeks = this._mergeWeeks(plan.weeks, parsed.newWeeks, currentWeekIndex);
    } catch (err) {
      logger.error('plan.revision.llm_failed', {
        planId,
        err: err instanceof Error ? err.message : String(err),
      });
      throw new Error('Failed to generate revision: ' + (err instanceof Error ? err.message : String(err)));
    }

    const updatedPlan = {
      ...plan,
      weeks: newWeeks,
      updatedAt: new Date().toISOString(),
    };

    await this.plans.update(plan.id, userId, {
      weeks: updatedPlan.weeks,
      updatedAt: updatedPlan.updatedAt,
    });

    const revisionId = uuid();
    const appliedAt = new Date().toISOString();
    const revision: PlanRevision = {
      id: revisionId,
      planId: plan.id,
      userId,
      weekIndex: currentWeekIndex,
      requestType: input.type as PlanRevisionRequestType,
      subOption: input.subOption,
      freeText: input.freeText,
      oldWeeksSnapshot,
      newWeeksSnapshot: updatedPlan.weeks.slice(currentWeekIndex),
      coachExplanation,
      status: 'applied',
      createdAt: now,
      appliedAt,
    };

    await this.revisions.save(revision);

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

    return { revision, updatedPlan };
  }

  private _getCurrentWeekIndex(plan: Plan): number {
    const now = new Date();
    const planDate = new Date(plan.createdAt);
    const diffTime = Math.abs(now.getTime() - planDate.getTime());
    const diffWeeks = Math.ceil(diffTime / (1000 * 60 * 60 * 24 * 7));
    return Math.min(diffWeeks, plan.weeksCount - 1);
  }

  private _buildLLMPrompt(
    plan: Plan,
    currentWeekIndex: number,
    input: RequestRevisionInput,
    profile: UserProfile,
    knowledgeContext: string,
  ): string {
    const futureWeeks = plan.weeks.slice(currentWeekIndex);
    const promptWeeksJson = JSON.stringify(futureWeeks, null, 2);

    return `Plano atual (semanas futuras a partir da semana ${currentWeekIndex + 1}):
${promptWeeksJson}

Solicitação do user:
- Tipo: ${input.type}
- Sub-opção: ${input.subOption ?? 'N/A'}
- Texto livre: ${input.freeText ?? 'N/A'}

Profile: nível=${profile.level}, objetivo=${profile.goal}, frequência=${profile.frequency}x/semana
${knowledgeContext ? `Exames recentes:
${knowledgeContext}` : ''}

Retorne JSON estrito no formato esperado.`;
  }

  private _getSystemPrompt(): string {
    return `Você é o Coach.AI do runnin. Modifique o plano de treino existente conforme a solicitação.

Regras:
1. Mantenha o objetivo do user
2. NÃO altere semanas já completadas/passadas
3. Modifique apenas semanas futuras a partir da atual
4. Se houver dados clínicos (exam summaries), respeite limites (FCmáx, limiar)
5. Preserve a periodização (não quebre estrutura linear 3:1)
6. Retorne APENAS JSON estrito conforme schema.`;
  }

  private _parseRevisionResponse(raw: string): { coachExplanation: string; newWeeks: z.infer<typeof PlanWeekSchema>[] } {
    try {
      const normalized = this._normalizeJson(raw);
      const parsed = RevisionResponseSchema.parse(normalized);
      return parsed;
    } catch (err) {
      throw new Error(`Invalid LLM response format: ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  private _normalizeJson(raw: string): unknown {
    let normalized = raw.replace(/\r/g, '').trim();
    normalized = this._stripMarkdownFences(normalized);

    const firstArray = normalized.indexOf('[');
    const lastArray = normalized.lastIndexOf(']');
    if (firstArray !== -1 && lastArray !== -1 && lastArray > firstArray) {
      normalized = normalized.slice(firstArray, lastArray + 1);
    }

    return JSON.parse(normalized) as unknown;
  }

  private _stripMarkdownFences(input: string): string {
    return input
      .replace(/```(?:json)?\s*/gi, '')
      .replace(/```/g, '')
      .trim();
  }

  private _mergeWeeks(
    originalWeeks: Plan['weeks'],
    newWeeks: z.infer<typeof PlanWeekSchema>[],
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
