import { v4 as uuid } from 'uuid';
import { z } from 'zod';
import { getAsyncLLM } from '@shared/infra/llm/llm.factory';
import { PlanRepository } from '../domain/plan.repository';
import { Plan, PlanSession, PlanWeek } from '../domain/plan.entity';
import { logger } from '@shared/logger/logger';
import { formatRunningKnowledgeContext } from '@shared/knowledge/running/running-knowledge';

const SYSTEM_PROMPT = `Você é um coach de corrida especialista. Gere um plano de treino estruturado em JSON válido.
O JSON deve ser um array de semanas. Cada semana tem weekNumber e sessions.
Cada sessão tem: dayOfWeek (1=Seg,7=Dom), type (Easy Run/Intervalado/Tempo Run/Long Run), distanceKm (number), targetPace (string opcional, ex: "6:00"), notes (string curta).
Retorne SOMENTE o JSON, sem explicação, sem markdown.
Nao invente justificativas cientificas fora da base fornecida.
Se o atleta for iniciante, seja conservador com intensidade e progressao.`;

const PlanSessionSchema = z.object({
  dayOfWeek: z.number().int().min(1).max(7),
  type: z.string().min(1),
  distanceKm: z.number().positive().max(60),
  targetPace: z.string().min(1).optional(),
  notes: z.string().default(''),
});

const PlanWeekSchema = z.object({
  weekNumber: z.number().int().min(1),
  sessions: z.array(PlanSessionSchema).max(7),
});

const PlanWeeksSchema = z.array(PlanWeekSchema);

export const GeneratePlanSchema = z.object({
  goal: z.string().min(1),
  level: z.enum(['iniciante', 'intermediario', 'avancado']),
  frequency: z.number().int().min(2).max(7).optional(),
  weeksCount: z.number().int().min(4).max(16).default(8),
});

export type GeneratePlanInput = z.infer<typeof GeneratePlanSchema>;

export class GeneratePlanUseCase {
  private llm = getAsyncLLM();

  constructor(private repo: PlanRepository) {}

  async execute(userId: string, input: GeneratePlanInput): Promise<Plan> {
    const planId = uuid();
    const now = new Date().toISOString();

    // Cria o plano como "generating" imediatamente
    const plan: Plan = {
      id: planId,
      userId,
      goal: input.goal,
      level: input.level,
      weeksCount: input.weeksCount,
      status: 'generating',
      weeks: [],
      createdAt: now,
      updatedAt: now,
    };
    await this.repo.create(plan);

    // Gera o plano em background
    this._generateAsync(plan, input).catch(err =>
      logger.error('plan.generate.background_failed', {
        planId,
        err: err instanceof Error ? err.message : String(err),
      }),
    );

    return plan;
  }

  private async _generateAsync(plan: Plan, input: GeneratePlanInput): Promise<void> {
    const freq =
        input.frequency ??
        (input.level === 'iniciante' ? 3 : input.level === 'intermediario' ? 4 : 5);
    const knowledgeContext = formatRunningKnowledgeContext(
      `${input.goal} ${input.level} ${input.weeksCount} semanas corrida`,
      5,
    );
    const prompt = `Gere um plano de corrida de ${input.weeksCount} semanas.
Objetivo: ${input.goal}
Nível: ${input.level}
Frequência: ${freq} dias por semana
Estruture o plano com predominio de baixa intensidade e distribuicao coerente de carga.
Evite regras fixas nao sustentadas por evidencia, como aumento automatico de 10% toda semana.
Inclua semanas de consolidacao ou alivio quando a carga estiver subindo.
Se houver prova-alvo nas ultimas semanas, reduza volume e preserve especificidade.

Base de conhecimento baseada em evidencia:
${knowledgeContext}

Requisitos:
- Retorne um array JSON com ${input.weeksCount} objetos de semana.
- O array deve conter weekNumber de 1 ate ${input.weeksCount}, sem agrupar varias semanas em um unico objeto.
- Cada semana deve ter exatamente ${freq} sessoes, salvo necessidade muito clara de uma semana de alivio.
- Distribua os dias para evitar sessoes duras em dias consecutivos.
- Em iniciantes, use no maximo 1 sessao de intensidade por semana.
- Em intermediarios e avancados, use no maximo 2 sessoes de qualidade por semana.
- Notes deve explicar o objetivo da sessao em portugues brasileiro, de forma curta.
- Se nao houver dados suficientes para pace exato, deixe targetPace ausente.
- Nao inclua sessoes de fortalecimento dentro do JSON; mencione isso em notes quando relevante.`;

    try {
      const raw = await this.llm.generate(prompt, {
        systemPrompt: SYSTEM_PROMPT,
        maxTokens: 6000,
      });
      const weeks = await this._parseWeeks(raw, input.weeksCount);
      await this.repo.update(plan.id, plan.userId, {
        status: 'ready',
        weeks,
        updatedAt: new Date().toISOString(),
      });
    } catch (err) {
      logger.error('plan.generate.failed', {
        planId: plan.id,
        err: err instanceof Error ? err.message : String(err),
      });
      await this.repo.update(plan.id, plan.userId, {
        status: 'failed',
        updatedAt: new Date().toISOString(),
      });
      throw err;
    }
  }

  private async _parseWeeks(raw: string, weeksCount: number): Promise<PlanWeek[]> {
    try {
      const normalized = this._normalizeWeeks(raw);
      return this._ensureWeeksCount(normalized, weeksCount);
    } catch (initialError) {
      const firstErrorMessage =
        initialError instanceof Error ? initialError.message : String(initialError);
      logger.warn('plan.parse.initial_failed', {
        err: firstErrorMessage,
      });

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
        },
      );

      try {
        const normalized = this._normalizeWeeks(repaired);
        return this._ensureWeeksCount(normalized, weeksCount);
      } catch (repairError) {
        const secondErrorMessage =
          repairError instanceof Error ? repairError.message : String(repairError);
        logger.warn('plan.parse.repair_failed', {
          err: secondErrorMessage,
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
            systemPrompt:
              'Voce e um reparador de JSON. Retorne apenas JSON valido e parseavel.',
            maxTokens: 3000,
            temperature: 0,
          },
        );

        const normalized = this._normalizeWeeks(repairedAgain);
        return this._ensureWeeksCount(normalized, weeksCount);
      }
    }
  }

  private _normalizeWeeks(raw: string): PlanWeek[] {
    const parsedJson = this._parseJsonLenient(raw);
    const parsed = PlanWeeksSchema.parse(this._extractWeeksCandidate(parsedJson));

    return parsed.map((week, weekIndex) => ({
      weekNumber: week.weekNumber || weekIndex + 1,
      sessions: week.sessions.map(session => ({
        id: uuid(),
        dayOfWeek: session.dayOfWeek,
        type: session.type,
        distanceKm: Number(session.distanceKm.toFixed(1)),
        targetPace: session.targetPace,
        notes: session.notes,
      }) satisfies PlanSession).sort((a, b) => {
        if (a.dayOfWeek !== b.dayOfWeek) return a.dayOfWeek - b.dayOfWeek;
        return a.id.localeCompare(b.id);
      }),
    }));
  }

  private _parseJsonLenient(raw: string): unknown {
    const candidates = this._buildJsonCandidates(raw);
    const errors: string[] = [];

    for (const candidate of candidates) {
      try {
        return JSON.parse(candidate) as unknown;
      } catch (err) {
        const parseError = err instanceof Error ? err.message : String(err);
        errors.push(parseError);

        try {
          const repaired = this._repairCommonJsonIssues(candidate);
          return JSON.parse(repaired) as unknown;
        } catch (repairErr) {
          errors.push(repairErr instanceof Error ? repairErr.message : String(repairErr));

          try {
            const repaired = this._repairCommonJsonIssues(candidate);
            const extracted =
              this._extractTopLevelJsonArray(repaired) ??
              this._extractTopLevelJsonObject(repaired);
            if (extracted) return JSON.parse(extracted) as unknown;
          } catch (extractErr) {
            errors.push(extractErr instanceof Error ? extractErr.message : String(extractErr));
          }
        }
      }
    }

    throw new Error(
      `Unable to parse plan JSON after ${candidates.length} attempts: ${errors.join(' | ')}`,
    );
  }

  private _buildJsonCandidates(raw: string): string[] {
    const normalized = raw.replace(/\r/g, '').trim();
    const withoutFences = this._stripMarkdownFences(normalized);
    const candidates: string[] = [];
    const add = (value: string | undefined) => {
      if (!value) return;
      const trimmed = value.trim();
      if (!trimmed) return;
      if (!candidates.includes(trimmed)) candidates.push(trimmed);
    };

    add(normalized);
    add(withoutFences);

    const fenceRegex = /```(?:json)?\s*([\s\S]*?)```/gi;
    for (const match of normalized.matchAll(fenceRegex)) {
      add(match[1]);
    }

    const firstArray = withoutFences.indexOf('[');
    const lastArray = withoutFences.lastIndexOf(']');
    if (firstArray !== -1 && lastArray !== -1 && lastArray > firstArray) {
      add(withoutFences.slice(firstArray, lastArray + 1));
    }
    add(this._extractTopLevelJsonArray(withoutFences));

    const firstObject = withoutFences.indexOf('{');
    const lastObject = withoutFences.lastIndexOf('}');
    if (firstObject !== -1 && lastObject !== -1 && lastObject > firstObject) {
      add(withoutFences.slice(firstObject, lastObject + 1));
    }
    add(this._extractTopLevelJsonObject(withoutFences));

    return candidates;
  }

  private _repairCommonJsonIssues(input: string): string {
    // Remove BOM and non-printable control characters that frequently break parsing.
    let repaired = this._stripMarkdownFences(input)
      .replace(/^\uFEFF/, '')
      .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, '');

    // Normalize smart quotes occasionally returned by LLMs.
    repaired = repaired
      .replace(/[“”]/g, '"')
      .replace(/[‘’]/g, "'");

    // Escape literal newlines/tabs that appear inside quoted strings.
    let escaped = '';
    let inString = false;
    let escapedChar = false;

    for (let i = 0; i < repaired.length; i++) {
      const ch = repaired[i];

      if (!inString) {
        if (ch === '"') inString = true;
        escaped += ch;
        continue;
      }

      if (escapedChar) {
        escaped += ch;
        escapedChar = false;
        continue;
      }

      if (ch === '\\') {
        escaped += ch;
        escapedChar = true;
        continue;
      }

      if (ch === '"') {
        let nextIndex = i + 1;
        while (nextIndex < repaired.length && /\s/.test(repaired[nextIndex])) nextIndex++;
        const nextChar = nextIndex < repaired.length ? repaired[nextIndex] : '';
        const isClosingQuote =
          !nextChar || nextChar === ':' || nextChar === ',' || nextChar === '}' || nextChar === ']';

        if (isClosingQuote) {
          escaped += ch;
          inString = false;
        } else {
          escaped += '\\"';
        }
        continue;
      }

      if (ch === '\n') {
        escaped += '\\n';
        continue;
      }

      if (ch === '\t') {
        escaped += '\\t';
        continue;
      }

      escaped += ch;
    }

    // Remove trailing commas before object/array terminators.
    let withoutTrailingCommas = escaped;
    while (/,(\s*[}\]])/.test(withoutTrailingCommas)) {
      withoutTrailingCommas = withoutTrailingCommas.replace(/,(\s*[}\]])/g, '$1');
    }

    const closed = this._closeUnbalancedJson(withoutTrailingCommas);
    return closed.trim();
  }

  private _stripMarkdownFences(input: string): string {
    return input
      .replace(/```(?:json|jsonc|javascript|js)?\s*/gi, '')
      .replace(/```/g, '')
      .trim();
  }

  private _extractTopLevelJsonArray(input: string): string | undefined {
    const start = input.indexOf('[');
    if (start === -1) return undefined;
    const end = this._findJsonBoundary(input, start, '[', ']');
    if (end === -1) return undefined;
    return input.slice(start, end + 1);
  }

  private _extractTopLevelJsonObject(input: string): string | undefined {
    const start = input.indexOf('{');
    if (start === -1) return undefined;
    const end = this._findJsonBoundary(input, start, '{', '}');
    if (end === -1) return undefined;
    return input.slice(start, end + 1);
  }

  private _findJsonBoundary(input: string, start: number, openChar: '[' | '{', closeChar: ']' | '}'): number {
    let depth = 0;
    let inString = false;
    let escapedChar = false;

    for (let i = start; i < input.length; i++) {
      const ch = input[i];

      if (inString) {
        if (escapedChar) {
          escapedChar = false;
          continue;
        }
        if (ch === '\\') {
          escapedChar = true;
          continue;
        }
        if (ch === '"') inString = false;
        continue;
      }

      if (ch === '"') {
        inString = true;
        continue;
      }
      if (ch === openChar) depth += 1;
      if (ch === closeChar) {
        depth -= 1;
        if (depth === 0) return i;
      }
    }

    return -1;
  }

  private _closeUnbalancedJson(input: string): string {
    let result = '';
    const stack: Array<']' | '}'> = [];
    let inString = false;
    let escapedChar = false;

    for (let i = 0; i < input.length; i++) {
      const ch = input[i];
      result += ch;

      if (inString) {
        if (escapedChar) {
          escapedChar = false;
          continue;
        }
        if (ch === '\\') {
          escapedChar = true;
          continue;
        }
        if (ch === '"') inString = false;
        continue;
      }

      if (ch === '"') {
        inString = true;
        continue;
      }
      if (ch === '{') {
        stack.push('}');
        continue;
      }
      if (ch === '[') {
        stack.push(']');
        continue;
      }
      if ((ch === '}' || ch === ']') && stack.length > 0 && stack[stack.length - 1] === ch) {
        stack.pop();
      }
    }

    if (inString) result += '"';
    while (stack.length > 0) {
      result += stack.pop();
    }

    return result;
  }

  private _extractWeeksCandidate(value: unknown): unknown {
    if (Array.isArray(value)) return value;
    if (!value || typeof value !== 'object') return value;

    const record = value as Record<string, unknown>;
    const arrayCandidateKeys = ['weeks', 'plan', 'schedule', 'trainingPlan', 'data'];
    for (const key of arrayCandidateKeys) {
      const candidate = record[key];
      if (Array.isArray(candidate)) return candidate;
    }

    if (
      typeof record['weekNumber'] === 'number' &&
      Array.isArray(record['sessions'])
    ) {
      return [record];
    }

    return value;
  }

  private async _ensureWeeksCount(weeks: PlanWeek[], weeksCount: number): Promise<PlanWeek[]> {
    const normalizedWeeks = this._renumberWeeks(weeks);
    if (normalizedWeeks.length === weeksCount) return normalizedWeeks;
    if (normalizedWeeks.length > weeksCount) {
      logger.warn('plan.parse.weeks_trimmed', {
        fromWeeks: normalizedWeeks.length,
        toWeeks: weeksCount,
      });
      return this._renumberWeeks(normalizedWeeks.slice(0, weeksCount));
    }

    const rebalancedRaw = await this.llm.generate(
      `Você recebeu um plano com ${normalizedWeeks.length} semanas e precisa devolver exatamente ${weeksCount}.
Expanda ou reestruture o plano mantendo o objetivo e a progressao.
Retorne SOMENTE um array JSON com ${weeksCount} objetos.
Os objetos devem ter weekNumber de 1 ate ${weeksCount}; nao agrupe varias semanas em um objeto.

Plano atual:
${JSON.stringify(normalizedWeeks)}`,
      {
        systemPrompt:
          'Retorne somente JSON valido no formato array de semanas com sessions.',
        maxTokens: 6000,
        temperature: 0.2,
      },
    );

    const rebalanced = this._normalizeWeeks(rebalancedRaw);
    if (rebalanced.length !== weeksCount) {
      logger.warn('plan.parse.weeks_rebalance_incomplete', {
        requestedWeeks: weeksCount,
        receivedWeeks: rebalanced.length,
      });
      return this._expandWeeksDeterministically(
        rebalanced.length > 0 ? rebalanced : normalizedWeeks,
        weeksCount,
      );
    }
    logger.warn('plan.parse.weeks_rebalanced', {
      fromWeeks: normalizedWeeks.length,
      toWeeks: rebalanced.length,
    });
    return this._renumberWeeks(rebalanced);
  }

  private _renumberWeeks(weeks: PlanWeek[]): PlanWeek[] {
    return weeks.map((week, index) => ({
      ...week,
      weekNumber: index + 1,
    }));
  }

  private _expandWeeksDeterministically(weeks: PlanWeek[], weeksCount: number): PlanWeek[] {
    if (weeks.length === 0) {
      throw new Error(`Expected ${weeksCount} weeks, received 0`);
    }

    const result = this._renumberWeeks(weeks).slice(0, weeksCount);
    while (result.length < weeksCount) {
      const source = result[result.length - 1];
      if (!source) break;

      const nextWeekNumber = result.length + 1;
      const isRecoveryWeek = nextWeekNumber % 4 === 0;
      const progressionFactor = isRecoveryWeek ? 0.85 : 1.05;

      result.push({
        weekNumber: nextWeekNumber,
        sessions: source.sessions.map(session => ({
          ...session,
          id: uuid(),
          distanceKm: Number(Math.max(1, session.distanceKm * progressionFactor).toFixed(1)),
          notes: this._deriveExpandedWeekNotes(session.notes, nextWeekNumber, isRecoveryWeek),
        })),
      });
    }

    logger.warn('plan.parse.weeks_expanded_locally', {
      fromWeeks: weeks.length,
      toWeeks: result.length,
    });

    return result;
  }

  private _deriveExpandedWeekNotes(notes: string, weekNumber: number, isRecoveryWeek: boolean): string {
    const suffix = isRecoveryWeek
      ? `Semana ${weekNumber}: consolidacao com carga reduzida.`
      : `Semana ${weekNumber}: progressao conservadora.`;
    if (!notes.trim()) return suffix;
    return `${notes} ${suffix}`;
  }
}
