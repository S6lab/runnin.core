import { v4 as uuid } from 'uuid';
import { z } from 'zod';
import { getAsyncLLM } from '@shared/infra/llm/llm.factory';
import { PlanRepository } from '../domain/plan.repository';
import { Plan, PlanSession, PlanWeek, HeartRateZones, GenerationProgress } from '../domain/plan.entity';
import { logger } from '@shared/logger/logger';
import { formatRunningKnowledgeContext } from '@shared/knowledge/running/running-knowledge';
import { UserRepository } from '@modules/users/domain/user.repository';
import { NotFoundError } from '@shared/errors/app-error';

const SYSTEM_PROMPT = `Você é o Coach.AI do runnin: um personal trainer de corrida experiente, presente e direto.
Gere um plano de treino estruturado em JSON válido.
O JSON deve ser um array de semanas. Cada semana tem weekNumber e sessions.
Cada sessão tem: dayOfWeek (1=Seg,7=Dom), type (Easy Run/Intervalado/Tempo Run/Long Run), distanceKm (number), targetPace (string opcional, ex: "6:00"), notes (string curta).
Retorne SOMENTE o JSON, sem explicação, sem markdown.
Nao invente justificativas cientificas fora da base fornecida.
Se o atleta for iniciante, seja conservador com intensidade e progressao.
As notes devem falar diretamente com o corredor, como um personal trainer: tom humano, motivador, firme e pratico.
Use frases curtas no imperativo ou primeira pessoa do plural, como "Segura o pace", "Vamos trabalhar base" e "Fecha leve para recuperar".
Evite texto robotico, explicacao academica longa ou linguagem de relatorio.`;

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
  goal: z.string().min(1).optional(), // Optional: defaults to user profile goal
  level: z.enum(['iniciante', 'intermediario', 'avancado']).optional(), // Optional: defaults to user profile level
  frequency: z.number().int().min(2).max(7).optional(), // Optional: defaults to user profile frequency
  weeksCount: z.number().int().min(4).max(16).optional(),
  birthDate: z.string().optional(), // For HR zone calculation (defaults to user profile)
  maxHeartRate: z.number().int().min(100).max(220).optional(), // User-provided max HR
});

export type GeneratePlanInput = z.infer<typeof GeneratePlanSchema>;

interface EnrichedPlanInput {
  goal: string;
  level: 'iniciante' | 'intermediario' | 'avancado';
  frequency?: number;
  weeksCount: number;
  birthDate?: string;
  maxHeartRate?: number;
}

export class GeneratePlanUseCase {
  private llm = getAsyncLLM();

  constructor(
    private repo: PlanRepository,
    private userRepo: UserRepository,
  ) {}

  async execute(userId: string, input: GeneratePlanInput): Promise<Plan> {
    // Stage 1: Fetch user profile to enrich plan input with assessment data
    const userProfile = await this.userRepo.findById(userId);
    if (!userProfile) {
      throw new NotFoundError('User profile not found. Please complete onboarding first.');
    }

    // Merge user profile data with input (input overrides profile)
    const enrichedInput: EnrichedPlanInput = {
      goal: input.goal ?? userProfile.goal,
      level: input.level ?? userProfile.level,
      frequency: input.frequency ?? userProfile.frequency,
      birthDate: input.birthDate ?? userProfile.birthDate,
      maxHeartRate: input.maxHeartRate,
      weeksCount: input.weeksCount ?? resolvePlanWeeksCount({
        goal: input.goal ?? userProfile.goal,
        level: input.level ?? userProfile.level,
        frequency: input.frequency ?? userProfile.frequency,
      }),
    };

    const planId = uuid();
    const now = new Date().toISOString();

    // Create plan as "generating" immediately
    const plan: Plan = {
      id: planId,
      userId,
      goal: enrichedInput.goal,
      level: enrichedInput.level,
      weeksCount: enrichedInput.weeksCount,
      status: 'generating',
      weeks: [],
      createdAt: now,
      updatedAt: now,
    };
    await this.repo.create(plan);

    // Generate plan in background
    this._generateAsync(plan, enrichedInput).catch(err =>
      logger.error('plan.generate.background_failed', {
        planId,
        err: err instanceof Error ? err.message : String(err),
      }),
    );

    return plan;
  }

  private async _updateProgress(
    planId: string,
    userId: string,
    stage: number,
    stageName: string,
    stageDescription: string,
  ): Promise<void> {
    const progress: GenerationProgress = {
      currentStage: stage,
      totalStages: 8,
      stageName,
      stageDescription,
    };
    await this.repo.update(planId, userId, {
      generationProgress: progress,
      updatedAt: new Date().toISOString(),
    });
  }

  private _calculateHeartRateZones(input: EnrichedPlanInput): HeartRateZones | undefined {
    let maxHR: number | undefined;

    if (input.maxHeartRate) {
      maxHR = input.maxHeartRate;
    } else if (input.birthDate) {
      const age = new Date().getFullYear() - new Date(input.birthDate).getUTCFullYear();
      maxHR = 220 - age; // Simple formula
    }

    if (!maxHR) return undefined;

    // Scientific HR zones per requirements:
    // Zone 1 (Easy): 60-70% max HR
    // Zone 2 (Aerobic): 70-80%
    // Zone 3 (Tempo): 80-87%
    // Zone 4 (Threshold): 87-93%
    // Zone 5 (VO2 Max): 93-100%
    return {
      zone1: { min: Math.round(maxHR * 0.6), max: Math.round(maxHR * 0.7) },
      zone2: { min: Math.round(maxHR * 0.7), max: Math.round(maxHR * 0.8) },
      zone3: { min: Math.round(maxHR * 0.8), max: Math.round(maxHR * 0.87) },
      zone4: { min: Math.round(maxHR * 0.87), max: Math.round(maxHR * 0.93) },
      zone5: { min: Math.round(maxHR * 0.93), max: Math.round(maxHR * 1.0) },
      maxHeartRate: maxHR,
    };
  }

  private _applyMesocyclePattern(weeks: PlanWeek[]): PlanWeek[] {
    return weeks.map((week) => {
      const isRecoveryWeek = week.weekNumber % 4 === 0;
      if (!isRecoveryWeek) return week;

      // Recovery week: reduce volume by 30-40% and keep only easy/recovery sessions
      const recoveryFactor = 0.65;
      return {
        ...week,
        sessions: week.sessions.map((session) => {
          const adjustedDistance = Number((session.distanceKm * recoveryFactor).toFixed(1));
          const isHighIntensity = session.type.toLowerCase().includes('interval') ||
            session.type.toLowerCase().includes('tempo') ||
            session.type.toLowerCase().includes('threshold');

          return {
            ...session,
            distanceKm: adjustedDistance,
            type: isHighIntensity ? 'Easy Run' : session.type,
            notes: `[Semana de recuperação] ${session.notes || 'Treino leve para consolidar adaptações.'}`,
          };
        }),
      };
    });
  }

  private async _generateAsync(
    plan: Plan,
    input: EnrichedPlanInput,
  ): Promise<void> {
    try {
      // Stage 1: Analyze user profile and assessment data
      await this._updateProgress(
        plan.id,
        plan.userId,
        1,
        'Analisando perfil',
        'Compreendendo seu nível, objetivo e histórico'
      );
      const freq =
        input.frequency ??
        (input.level === 'iniciante' ? 3 : input.level === 'intermediario' ? 4 : 5);

      // Stage 2: Calculate heart rate zones (if available)
      await this._updateProgress(
        plan.id,
        plan.userId,
        2,
        'Calculando zonas de frequência cardíaca',
        'Definindo zonas de treino personalizadas'
      );
      const heartRateZones = this._calculateHeartRateZones(input);

      // Stage 3: Determine weekly volume and frequency
      await this._updateProgress(
        plan.id,
        plan.userId,
        3,
        'Determinando volume semanal',
        'Calculando quilometragem e frequência ideal'
      );
      // Volume calculation happens in the LLM prompt

      // Stage 4: Generate mesocycle structure (4 weeks with 3:1 pattern)
      await this._updateProgress(
        plan.id,
        plan.userId,
        4,
        'Gerando estrutura do mesociclo',
        'Criando ciclo de 4 semanas com periodização 3:1'
      );

      const knowledgeContext = await formatRunningKnowledgeContext(
        `${input.goal} ${input.level} ${input.weeksCount} semanas corrida`,
        5,
      );

      // Stage 5: Create individual sessions with targets
      await this._updateProgress(
        plan.id,
        plan.userId,
        5,
        'Criando sessões individuais',
        'Gerando treinos específicos com objetivos'
      );

      const hrZoneContext = heartRateZones
        ? `\n\nZonas de frequência cardíaca do atleta:
- Zona 1 (Recuperação): ${heartRateZones.zone1.min}-${heartRateZones.zone1.max} bpm
- Zona 2 (Fácil): ${heartRateZones.zone2.min}-${heartRateZones.zone2.max} bpm
- Zona 3 (Tempo): ${heartRateZones.zone3.min}-${heartRateZones.zone3.max} bpm
- Zona 4 (Limiar): ${heartRateZones.zone4.min}-${heartRateZones.zone4.max} bpm
- Zona 5 (VO2max): ${heartRateZones.zone5.min}-${heartRateZones.zone5.max} bpm
Use essas zonas para orientar a intensidade dos treinos.`
        : '';

      const prompt = `Gere um plano de corrida de ${input.weeksCount} semanas com periodização 3:1 (3 semanas de carga + 1 semana de recuperação).
Objetivo: ${input.goal}
Nível: ${input.level}
Frequência: ${freq} dias por semana

**PERIODIZAÇÃO 3:1 OBRIGATÓRIA:**
- A cada 4 semanas, aplique o padrão 3:1: 3 semanas de carga progressiva + 1 semana de recuperação
- Semanas 1-3: aumente volume/intensidade gradualmente
- Semana 4: reduza volume em 30-40% para recuperação ativa
- Semanas 5-7: retome carga progressiva (começando acima da semana 3)
- Semana 8: nova semana de recuperação
- Continue esse padrão até completar ${input.weeksCount} semanas
- A semana de recuperação mantém a frequência mas reduz distância e intensidade

Estruture o plano com predominio de baixa intensidade e distribuicao coerente de carga.
Evite regras fixas nao sustentadas por evidencia, como aumento automatico de 10% toda semana.
Se houver prova-alvo nas ultimas semanas, reduza volume e preserve especificidade.
${hrZoneContext}

Base de conhecimento baseada em evidencia:
${knowledgeContext}

Requisitos:
- Retorne um array JSON com ${input.weeksCount} objetos de semana.
- O array deve conter weekNumber de 1 ate ${input.weeksCount}, sem agrupar varias semanas em um unico objeto.
- Cada semana deve ter exatamente ${freq} sessoes, salvo semanas de recuperacao que podem ter ${Math.max(freq - 1, 3)}.
- Distribua os dias para evitar sessoes duras em dias consecutivos.
- Em iniciantes, use no maximo 1 sessao de intensidade por semana.
- Em intermediarios e avancados, use no maximo 2 sessoes de qualidade por semana.
- Nas semanas de recuperação (4, 8, 12, 16), reduza distâncias e priorize treinos Easy/Recuperação.
- Notes deve explicar o objetivo da sessao em portugues brasileiro, de forma curta.
- Notes deve soar como uma orientacao de personal trainer para o corredor: direta, motivadora, pratica e natural.
- Fale com o corredor em segunda pessoa ou primeira pessoa do plural ("voce", "vamos", "mantem", "fecha").
- Se nao houver dados suficientes para pace exato, deixe targetPace ausente.
- Nao inclua sessoes de fortalecimento dentro do JSON; mencione isso em notes quando relevante.`;

      const raw = await this.llm.generate(prompt, {
        systemPrompt: SYSTEM_PROMPT,
        maxTokens: 6000,
      });

      // Stage 6: Apply periodization rules
      await this._updateProgress(
        plan.id,
        plan.userId,
        6,
        'Aplicando regras de periodização',
        'Ajustando carga e recuperação'
      );
      let weeks = await this._parseWeeks(raw, input.weeksCount);

      // Apply 3:1 mesocycle pattern explicitly
      weeks = this._applyMesocyclePattern(weeks);

      // Stage 7: Add coach briefings per session
      await this._updateProgress(
        plan.id,
        plan.userId,
        7,
        'Adicionando briefings do coach',
        'Personalizando orientações para cada treino'
      );
      // Notes are already included from LLM, but we mark the week type
      weeks = weeks.map(week => ({
        ...week,
        weekType: week.weekNumber % 4 === 0 ? 'recovery' : 'load',
      }));

      // Stage 8: Persist plan to database
      await this._updateProgress(
        plan.id,
        plan.userId,
        8,
        'Salvando plano',
        'Finalizando seu plano personalizado'
      );

      await this.repo.update(plan.id, plan.userId, {
        status: 'ready',
        weeks,
        heartRateZones,
        generationProgress: undefined, // Clear progress when done
        updatedAt: new Date().toISOString(),
      });
    } catch (err) {
      logger.error('plan.generate.failed', {
        planId: plan.id,
        err: err instanceof Error ? err.message : String(err),
      });
      await this.repo.update(plan.id, plan.userId, {
        status: 'failed',
        generationProgress: undefined,
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
      ? `Semana ${weekNumber}: baixa a carga, respira e consolida o ganho.`
      : `Semana ${weekNumber}: vamos subir com controle, sem forcar alem da conta.`;
    if (!notes.trim()) return suffix;
    return `${notes} ${suffix}`;
  }
}

export function resolvePlanWeeksCount(input: { goal: string; level: string; frequency?: number }): number {
  const goal = normalizeGoal(input.goal);
  const frequency = Math.min(Math.max(input.frequency ?? 3, 1), 7);
  const isBeginner = input.level === 'iniciante';
  const isAdvanced = input.level === 'avancado';

  let weeks: number;
  if (goal.includes('maratona') || goal.includes('42')) {
    weeks = isAdvanced ? 14 : 16;
  } else if (goal.includes('meia') || goal.includes('21') || goal.includes('half')) {
    weeks = isBeginner ? 14 : isAdvanced ? 10 : 12;
  } else if (goal.includes('10k') || goal.includes('10 km')) {
    weeks = isBeginner ? 10 : 8;
  } else if (goal.includes('5k') || goal.includes('5 km')) {
    weeks = isBeginner ? 8 : 6;
  } else if (goal.includes('emagrec') || goal.includes('saude') || goal.includes('condicion')) {
    weeks = isAdvanced ? 6 : 8;
  } else {
    weeks = isBeginner ? 8 : isAdvanced ? 10 : 8;
  }

  if (frequency <= 2) {
    weeks += 2;
  } else if (frequency >= 5 && !isBeginner && weeks > 8) {
    weeks -= 2;
  }

  return Math.min(Math.max(weeks, 4), 16);
}

function normalizeGoal(goal: string): string {
  return goal
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/ç/g, 'c');
}
