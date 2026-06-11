import { z } from 'zod';
import { getPlanLLM } from '@shared/infra/llm/llm.factory';
import { LLMProvider } from '@shared/infra/llm/llm.interface';
import { buildPlanInitPrompt } from '@shared/infra/llm/prompts';
import { formatRunningKnowledgeContext } from '@shared/knowledge/running/running-knowledge';
import { logger } from '@shared/logger/logger';
import { parseJsonLenient, extractWeeksCandidate, coerceWeeksLenient } from './json-lenient';
import { RawPlanWeeksSchema, RawPlanWeek } from './raw-weeks.schema';

/**
 * Geração das semanas do plano: prompt (plan-init) + LLM JSON mode +
 * parse leniente + repair (2 tentativas LLM) + garantia best-effort de
 * weeksCount (rebalance LLM). NÃO faz hidratação de domínio (ids,
 * segments, clamps, two-tier) — isso é do caller (runnin-api).
 */

export const GenerateWeeksRequestSchema = z.object({
  /** Pra atribuição de llm_usage. Vem do BFF (rota é s2s, sem token de user). */
  userId: z.string().min(1),
  /** Snippet do perfil — shape do UserProfile do caller, validado leve. */
  profile: z.record(z.string(), z.unknown()).nullable(),
  biometricSummary: z
    .object({
      windowDays: z.number(),
      avgRestingBpm: z.number().nullable(),
      maxBpm: z.number().nullable(),
      avgSleepHours: z.number().nullable(),
      totalSteps: z.number().nullable(),
      avgHrv: z.number().nullable(),
      latestWeight: z.number().nullable(),
      sampleCount: z.number(),
    })
    .nullish(),
  input: z.object({
    goal: z.string().min(1),
    level: z.string().min(1),
    frequency: z.number().int().min(1).max(7),
    weeksCount: z.number().int().min(1).max(40),
    startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    levelHint: z.string().nullish(),
    currentWeeklyKm: z.number().nullish(),
    currentPaceMinKm: z.string().nullish(),
    capacityDistanceKm: z.number().nullish(),
    availableDays: z.array(z.number().int().min(1).max(7)).nullish(),
    goalKind: z.enum(['flow', 'race']).optional(),
    flowSubgoal: z.enum(['start', 'improve', 'injury_return', 'postpartum']).optional(),
    raceDistanceKm: z.number().optional(),
    raceMode: z.enum(['complete', 'improve_pace']).optional(),
    targetPaceMinKm: z.string().optional(),
    windowMode: z.enum(['aggressive', 'feasible', 'safe']).optional(),
    longRunDayOfWeek: z.number().int().min(1).max(7).optional(),
    longRunMaxMinutes: z.number().optional(),
    raceDate: z.string().optional(),
  }),
});

export type GenerateWeeksRequest = z.infer<typeof GenerateWeeksRequestSchema>;

export interface GenerateWeeksResult {
  weeks: RawPlanWeek[];
  /** true quando nem o rebalance LLM bateu weeksCount — caller expande
   *  deterministicamente. */
  countMismatch: boolean;
  meta: { promptVersion: string; promptSource: string };
}

export class GenerateWeeksUseCase {
  constructor(private readonly llm: LLMProvider = getPlanLLM()) {}

  async execute(req: GenerateWeeksRequest): Promise<GenerateWeeksResult> {
    const { userId, profile, biometricSummary, input } = req;

    const ragContext = await formatRunningKnowledgeContext(
      `${input.goal} ${input.level} ${input.weeksCount} semanas corrida`,
      5,
    );

    const built = await buildPlanInitPrompt({
      profile: profile as never,
      biometricSummary: biometricSummary ?? null,
      input,
      ragContext,
    });

    const raw = await this.llm.generate(built.userPrompt, {
      systemPrompt: built.systemPrompt,
      maxTokens: built.maxTokens,
      temperature: built.temperature,
      userId,
      useCase: 'generate-plan',
      // JSON mode: Gemini garante schema válido. Elimina ~90% das falhas
      // de parse que levavam plano a status "failed".
      responseJson: true,
    });

    let weeks = await this._parseWithRepair(raw, userId);
    let countMismatch = false;

    if (weeks.length > input.weeksCount) {
      logger.warn('plan.parse.weeks_trimmed', {
        fromWeeks: weeks.length,
        toWeeks: input.weeksCount,
      });
      weeks = weeks.slice(0, input.weeksCount);
    } else if (weeks.length < input.weeksCount) {
      const rebalanced = await this._rebalanceCount(weeks, input.weeksCount, userId);
      if (rebalanced) {
        weeks = rebalanced;
      } else {
        countMismatch = true;
      }
    }

    return {
      weeks: this._renumber(weeks),
      countMismatch,
      meta: { promptVersion: built.version, promptSource: built.source },
    };
  }

  /** Parse leniente + até 2 repairs via LLM (mesma cadeia do legado). */
  private async _parseWithRepair(raw: string, userId: string): Promise<RawPlanWeek[]> {
    try {
      return this._normalize(raw);
    } catch (initialError) {
      const firstErrorMessage =
        initialError instanceof Error ? initialError.message : String(initialError);
      logger.warn('plan.parse.initial_failed', { err: firstErrorMessage });
      logger.warn('plan.parse.raw_sample', { sample: raw.slice(0, 800), rawLen: raw.length });

      const repaired = await this.llm.generate(
        `Converta a resposta abaixo em JSON valido estritamente no formato esperado.
Erro identificado no parse: ${firstErrorMessage}
Resposta original:
${raw}`,
        {
          systemPrompt:
            'Retorne somente JSON valido. Preserve o conteudo util e descarte texto fora do JSON.',
          maxTokens: 3000,
          temperature: 0,
          responseJson: true,
          userId,
          useCase: 'generate-plan',
        },
      );

      try {
        return this._normalize(repaired);
      } catch (repairError) {
        logger.warn('plan.parse.repair_failed', {
          err: repairError instanceof Error ? repairError.message : String(repairError),
        });

        const repairedAgain = await this.llm.generate(
          `Repare o JSON de plano abaixo.
Regras obrigatorias:
- Retorne somente JSON.
- O JSON deve ser array de semanas com sessions.
- Escape corretamente aspas e quebras de linha em strings.
- Nao inclua comentarios.

Conteudo recebido:
${repaired}`,
          {
            systemPrompt: 'Voce e um reparador de JSON. Retorne apenas JSON valido e parseavel.',
            responseJson: true,
            maxTokens: 3000,
            temperature: 0,
            userId,
            useCase: 'generate-plan',
          },
        );

        return this._normalize(repairedAgain);
      }
    }
  }

  private _normalize(raw: string): RawPlanWeek[] {
    const parsedJson = parseJsonLenient(raw);
    const candidate = extractWeeksCandidate(parsedJson);
    const lenient = coerceWeeksLenient(candidate);
    return RawPlanWeeksSchema.parse(lenient);
  }

  /**
   * Rebalance LLM quando o count veio menor que o pedido. Retorna null se
   * ainda não bateu — caller (runnin-api) expande deterministicamente.
   */
  private async _rebalanceCount(
    weeks: RawPlanWeek[],
    weeksCount: number,
    userId: string,
  ): Promise<RawPlanWeek[] | null> {
    const normalizedWeeks = this._renumber(weeks);
    const rebalancedRaw = await this.llm.generate(
      `Você recebeu um plano com ${normalizedWeeks.length} semanas e precisa devolver exatamente ${weeksCount}.
Expanda ou reestruture o plano mantendo o objetivo e a progressao.
Retorne SOMENTE um array JSON com ${weeksCount} objetos.
Os objetos devem ter weekNumber de 1 ate ${weeksCount}; nao agrupe varias semanas em um objeto.

Plano atual:
${JSON.stringify(normalizedWeeks)}`,
      {
        systemPrompt: 'Retorne somente JSON valido no formato array de semanas com sessions.',
        maxTokens: 6000,
        temperature: 0.2,
        userId,
        useCase: 'generate-plan',
      },
    );

    try {
      const rebalanced = this._normalize(rebalancedRaw);
      if (rebalanced.length !== weeksCount) {
        logger.warn('plan.parse.weeks_rebalance_incomplete', {
          requestedWeeks: weeksCount,
          receivedWeeks: rebalanced.length,
        });
        return null;
      }
      logger.warn('plan.parse.weeks_rebalanced', {
        fromWeeks: normalizedWeeks.length,
        toWeeks: rebalanced.length,
      });
      return this._renumber(rebalanced);
    } catch (err) {
      logger.warn('plan.parse.weeks_rebalance_failed', {
        err: err instanceof Error ? err.message : String(err),
      });
      return null;
    }
  }

  private _renumber(weeks: RawPlanWeek[]): RawPlanWeek[] {
    return weeks.map((week, index) => ({ ...week, weekNumber: index + 1 }));
  }
}
