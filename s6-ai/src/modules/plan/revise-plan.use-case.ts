import { z } from 'zod';
import { getAsyncLLM } from '@shared/infra/llm/llm.factory';
import { LLMProvider } from '@shared/infra/llm/llm.interface';
import { buildPlanRevisionPrompt } from '@shared/infra/llm/prompts';
import { formatRunningKnowledgeContext } from '@shared/knowledge/running/running-knowledge';
import { logger } from '@shared/logger/logger';
import { parseJsonLenient } from './json-lenient';
import { RevisionResponseSchema, RevisionResponse } from './raw-weeks.schema';

/**
 * Revisão de plano: prompt (plan-revision) + LLM JSON mode + parse +
 * 1 repair LLM. Quota, merge de weeks, invariantes de race week e
 * persistência ficam no caller (runnin-api).
 */

export const RevisePlanRequestSchema = z.object({
  userId: z.string().min(1),
  profile: z.record(z.string(), z.unknown()).nullable(),
  plan: z.object({
    goal: z.string(),
    level: z.string(),
    weeksCount: z.number().int().positive(),
    /** Apenas as semanas FUTURAS (a partir da corrente) — shape do caller. */
    weeks: z.array(z.record(z.string(), z.unknown())),
    raceDate: z.string().nullish(),
    raceDayOfWeek: z.number().int().min(1).max(7).nullish(),
  }),
  revision: z.object({
    type: z.string().min(1),
    subOption: z.string().optional(),
    freeText: z.string().optional(),
  }),
  currentWeekNumber: z.number().int().positive(),
});

export type RevisePlanRequest = z.infer<typeof RevisePlanRequestSchema>;

export class RevisePlanUseCase {
  constructor(private readonly llm: LLMProvider = getAsyncLLM()) {}

  async execute(req: RevisePlanRequest): Promise<RevisionResponse & {
    meta: { promptVersion: string; promptSource: string };
  }> {
    const ragContext = await formatRunningKnowledgeContext(
      `${req.plan.goal} ${req.plan.level} corrida plano de ${req.plan.weeksCount} semanas`,
      5,
    );

    const built = await buildPlanRevisionPrompt({
      profile: req.profile as never,
      plan: {
        goal: req.plan.goal,
        level: req.plan.level,
        weeksCount: req.plan.weeksCount,
        weeks: req.plan.weeks as never,
        raceDate: req.plan.raceDate ?? undefined,
        raceDayOfWeek: req.plan.raceDayOfWeek ?? undefined,
      } as never,
      revision: req.revision,
      currentWeekNumber: req.currentWeekNumber,
      ragContext,
    });

    const raw = await this.llm.generate(built.userPrompt, {
      systemPrompt: built.systemPrompt,
      maxTokens: built.maxTokens,
      temperature: built.temperature,
      userId: req.userId,
      useCase: 'plan-revision-manual',
      responseJson: true,
    });

    let parsed: RevisionResponse;
    try {
      parsed = this._parse(raw);
    } catch (firstErr) {
      const msg = firstErr instanceof Error ? firstErr.message : String(firstErr);
      logger.warn('plan.revision.parse_failed_retrying', { err: msg });
      const repaired = await this.llm.generate(
        `Converta a resposta abaixo em JSON valido com shape {"coachExplanation": string, "newWeeks": [...]}.
Erro identificado: ${msg}
Resposta original:
${raw}`,
        {
          systemPrompt: 'Retorne somente JSON valido. Preserve o conteudo util.',
          maxTokens: built.maxTokens,
          temperature: 0,
          responseJson: true,
          userId: req.userId,
          useCase: 'plan-revision-manual',
        },
      );
      parsed = this._parse(repaired);
    }

    logger.info('plan.revision.generated', {
      userId: req.userId,
      version: built.version,
      source: built.source,
      newWeeks: parsed.newWeeks.length,
    });

    return {
      ...parsed,
      meta: { promptVersion: built.version, promptSource: built.source },
    };
  }

  private _parse(raw: string): RevisionResponse {
    const json = parseJsonLenient(raw);
    return RevisionResponseSchema.parse(json);
  }
}
