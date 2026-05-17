import { v4 as uuid } from 'uuid';
import { z } from 'zod';
import { getAsyncLLM } from '@shared/infra/llm/llm.factory';
import { PlanRepository } from '../domain/plan.repository';
import { Plan, PlanSession, PlanWeek } from '../domain/plan.entity';
import { logger } from '@shared/logger/logger';
import { formatRunningKnowledgeContext } from '@shared/knowledge/running/running-knowledge';
import { buildPlanInitPrompt } from '@shared/infra/llm/prompts';
import { CoachRuntimeContextService } from '@modules/coach/use-cases/coach-runtime-context.service';
import { container } from '@shared/container';
import { CooldownError } from '@shared/errors/app-error';

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
  weeksCount: z.number().int().min(4).max(16).optional(),
});

export type GeneratePlanInput = z.infer<typeof GeneratePlanSchema>;

export class GeneratePlanUseCase {
  private llm = getAsyncLLM();
  private runtime = new CoachRuntimeContextService();

  constructor(private repo: PlanRepository) {}

  async execute(userId: string, input: GeneratePlanInput, opts: { confirmOverwrite?: boolean } = {}): Promise<Plan> {
    // Limite: 1 plano ativo por user. Pra mudar, usar /plans/:id/request-revision
    // (rate-limited 1/semana). Overwrite explícito permitido com confirmOverwrite=true.
    const existing = await this.repo.findCurrent(userId);
    if (existing && existing.status !== 'failed' && !opts.confirmOverwrite) {
      const err = new Error('Você já tem um plano ativo. Confirme a substituição ou use a revisão semanal.');
      (err as Error & { code?: string }).code = 'PLAN_ALREADY_EXISTS';
      throw err;
    }

    // Overwrite quota: pro user pode substituir plano 1x/semana.
    // Primeiro plano (sem existing ativo) não consome quota.
    if (existing && existing.status !== 'failed' && opts.confirmOverwrite) {
      const profile = await container.repos.users.findById(userId);
      const quota = profile?.planRevisions ?? { usedThisWeek: 0, max: 1, resetAt: new Date().toISOString() };
      const resetAt = new Date(quota.resetAt);
      const now = new Date();
      // Se janela semanal expirou, reseta
      if (resetAt < now) {
        quota.usedThisWeek = 0;
        // próxima janela: 7 dias a partir de agora
        quota.resetAt = new Date(now.getTime() + 7 * 24 * 3600 * 1000).toISOString();
      }
      if (quota.usedThisWeek >= quota.max) {
        throw new CooldownError(
          quota.resetAt,
          `Limite semanal de novo plano atingido (${quota.max}/semana). Disponível em ${quota.resetAt}.`,
        );
      }
      // Consome 1 unidade da quota
      quota.usedThisWeek += 1;
      if (profile) {
        await container.repos.users.upsert({
          ...profile,
          planRevisions: quota,
          updatedAt: now.toISOString(),
        });
      }
    }

    const planId = uuid();
    const now = new Date().toISOString();
    const weeksCount = input.weeksCount ?? resolvePlanWeeksCount(input);

    // Cria o plano como "generating" imediatamente
    const plan: Plan = {
      id: planId,
      userId,
      goal: input.goal,
      level: input.level,
      weeksCount,
      status: 'generating',
      weeks: [],
      createdAt: now,
      updatedAt: now,
    };
    await this.repo.create(plan);

    // Gera o plano em background
    this._generateAsync(plan, { ...input, weeksCount }).catch(err =>
      logger.error('plan.generate.background_failed', {
        planId,
        err: err instanceof Error ? err.message : String(err),
      }),
    );

    return plan;
  }

  private async _generateAsync(
    plan: Plan,
    input: GeneratePlanInput & { weeksCount: number },
  ): Promise<void> {
    const freq =
        input.frequency ??
        (input.level === 'iniciante' ? 3 : input.level === 'intermediario' ? 4 : 5);

    const runtime = await this.runtime.getContext(plan.userId);
    const knowledgeContext = await formatRunningKnowledgeContext(
      `${input.goal} ${input.level} ${input.weeksCount} semanas corrida`,
      5,
    );

    const built = await buildPlanInitPrompt({
      profile: runtime.profile,
      input: { goal: input.goal, level: input.level, frequency: freq, weeksCount: input.weeksCount },
      ragContext: knowledgeContext,
    });

    const startedAt = Date.now();
    try {
      const llmStart = Date.now();
      const raw = await this.llm.generate(built.userPrompt, {
        systemPrompt: built.systemPrompt,
        maxTokens: built.maxTokens,
        temperature: built.temperature,
      });
      const llmMs = Date.now() - llmStart;
      const parseStart = Date.now();
      const weeks = await this._parseWeeks(raw, input.weeksCount);
      const parseMs = Date.now() - parseStart;
      const totalMs = Date.now() - startedAt;
      logger.info('plan.generate.completed', {
        planId: plan.id,
        version: built.version,
        source: built.source,
        llmMs,
        parseMs,
        totalMs,
        weeksCount: input.weeksCount,
      });
      await this.repo.update(plan.id, plan.userId, {
        status: 'ready',
        weeks,
        updatedAt: new Date().toISOString(),
      });
      // Fire-and-forget: gera narrativa longa pra página de detalhe sem
      // bloquear a resposta. Se falhar, o plano segue funcional sem texto.
      void this._generateCoachRationale(plan, weeks, runtime.profile);
      // Gera narrativas curtas per-week + mesocycle. Roda em paralelo
      // ao rationale longo. Falha silenciosa.
      void this._generateWeekNarratives(plan, weeks, runtime.profile);
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

  private async _generateCoachRationale(
    plan: Plan,
    weeks: PlanWeek[],
    profile: import('@modules/coach/use-cases/coach-runtime-context.service').CoachRuntimeProfile | null,
  ): Promise<void> {
    try {
      const totalKm = weeks.reduce(
        (s, w) => s + w.sessions.reduce((ss, x) => ss + x.distanceKm, 0),
        0,
      );
      const sessionsBySection = weeks
        .map((w, i) => `Semana ${i + 1}: ${w.sessions.length} sessões / ${w.sessions.reduce((s, x) => s + x.distanceKm, 0).toFixed(1)}km`)
        .join('\n');
      const profileLines = profile
        ? [
            `- Nome: ${profile.name ?? '—'}`,
            `- Nível: ${profile.level ?? '—'}`,
            `- Objetivo: ${profile.goal ?? '—'}`,
            `- Frequência alvo: ${profile.frequency ?? '—'}x/semana`,
            `- Período preferido: ${profile.runPeriod ?? '—'}`,
            `- Idade: ${profile.birthDate ?? '—'}`,
            `- Peso: ${profile.weight ?? '—'} | Altura: ${profile.height ?? '—'}`,
            `- FC repouso: ${profile.restingBpm ?? '—'} | FC máx: ${profile.maxBpm ?? '—'}`,
            `- Condições médicas: ${(profile.medicalConditions ?? []).join(', ') || 'nenhuma'}`,
            `- Wearable conectado: ${profile.hasWearable ? 'sim' : 'não'}`,
            `- Persona do coach: ${profile.coachPersonality ?? 'motivador'}`,
          ].join('\n')
        : '(perfil não disponível)';

      const userPrompt = `Você é o Coach AI do runnin. Escreva uma explicação clara e direta (markdown, 350-500 palavras max) sobre o plano que VOCÊ acabou de gerar pra esse atleta. Foco: o "porquê" das decisões.

# Dados do atleta considerados
${profileLines}

# Plano gerado
- Objetivo: ${plan.goal}
- Nível: ${plan.level}
- Duração: ${plan.weeksCount} semanas
- Volume total: ${totalKm.toFixed(1)}km

${sessionsBySection}

Estrutura esperada do markdown (use ##/### headings):
## Estratégia
2-3 frases sobre como o objetivo + nível dele orientaram a periodização.
## Como li seu perfil
3-5 bullets com observações específicas que afetaram o plano (ex: "FC máx alta sugere boa capacidade aeróbica → mais tempo na zona 3").
## Distribuição da carga
Bullets sobre como volume + intensidade são distribuídos nas semanas (progressão linear? 3:1? deload?).
## Recomendações
3-4 bullets curtos: alimentação, recuperação, sinais de alerta. Específicos ao perfil dele.
## O que vou ajustar com o tempo
1 parágrafo curto sobre como cada corrida vai ajustar próximas sessões.

NUNCA invente dados que não estão no perfil. Se um campo está vazio, ignore. Seja conciso. Use "você" pra falar com o atleta.`;

      const raw = await this.llm.generate(userPrompt, {
        systemPrompt: 'Você é o Coach AI do runnin. Tom: confiante, técnico mas acessível. Não use emojis. Português BR.',
        maxTokens: 1200,
        temperature: 0.4,
      });

      await this.repo.update(plan.id, plan.userId, {
        coachRationale: raw.trim(),
        updatedAt: new Date().toISOString(),
      });
      logger.info('plan.rationale.generated', { planId: plan.id, chars: raw.length });
    } catch (err) {
      logger.warn('plan.rationale.failed', {
        planId: plan.id,
        err: err instanceof Error ? err.message : String(err),
      });
      // não falha — plano segue válido sem rationale
    }
  }

  /**
   * Gera 1 narrativa curta (1-2 frases) por semana + 1 narrativa de
   * mesociclo (3-4 frases) personalizada pelo perfil do user. 1 chamada
   * LLM produz tudo em JSON pra evitar N chamadas. Fire-and-forget.
   */
  private async _generateWeekNarratives(
    plan: Plan,
    weeks: PlanWeek[],
    profile: import('@modules/coach/use-cases/coach-runtime-context.service').CoachRuntimeProfile | null,
  ): Promise<void> {
    if (weeks.length === 0) return;
    try {
      const weeksDigest = weeks.map((w, i) => {
        const sessions = w.sessions
          .map(s => `${this._dowName(s.dayOfWeek)} ${s.type} ${s.distanceKm.toFixed(1)}km`)
          .join(' · ');
        const km = w.sessions.reduce((a, x) => a + x.distanceKm, 0).toFixed(1);
        return `Semana ${i + 1}: ${w.sessions.length} sessões, ${km}km — ${sessions}`;
      }).join('\n');

      const profileLine = profile
        ? `Perfil: ${profile.level}, objetivo "${profile.goal}", ${profile.frequency ?? '?'}x/sem, FC máx ${profile.maxBpm ?? '?'}, persona "${profile.coachPersonality ?? 'motivador'}"`
        : 'Perfil indisponível';

      const userPrompt = `Você é o Coach AI do runnin. Produza narrativas curtas e personalizadas pra cada semana do plano + 1 narrativa de mesociclo. Responda APENAS JSON estritamente neste schema:

{
  "mesocycle": "string (3-4 frases sobre estratégia geral do mesociclo de ${plan.weeksCount} semanas, conectando ao perfil/objetivo)",
  "weeks": [
    { "weekNumber": 1, "narrative": "string (1-2 frases sobre foco específico da semana 1 e como ela serve o objetivo do user)" },
    { "weekNumber": 2, "narrative": "string idem" },
    ...
  ]
}

Regras:
- weeks tem exatamente ${weeks.length} elementos (1 por semana do plano).
- Narrativas SÃO personalizadas (nunca template "vamos combinar..."). Cite o ${profile?.level ?? 'nível'} e objetivo quando relevante.
- Use linguagem direta, "você", português BR.
- Sem emojis, sem markdown.
- Mesociclo: por que essas ${plan.weeksCount} semanas nessa ordem? Quando intensifica? Quando recupera?
- Cada semana: foco da semana + sessão-chave + o que muda da anterior. Conciso.

${profileLine}

Estrutura do plano:
${weeksDigest}`;

      const raw = await this.llm.generate(userPrompt, {
        systemPrompt: 'Você é o Coach AI do runnin. Retorne SOMENTE JSON válido. Sem comentários, sem texto fora do JSON.',
        maxTokens: 1500,
        temperature: 0.4,
      });

      const parsed = this._parseNarrativesJson(raw);
      if (!parsed) return;

      const enriched: PlanWeek[] = weeks.map((w) => {
        const match = parsed.weeks.find((x) => x.weekNumber === w.weekNumber);
        return match ? { ...w, narrative: match.narrative } : w;
      });

      await this.repo.update(plan.id, plan.userId, {
        weeks: enriched,
        mesocycleNarrative: parsed.mesocycle,
        updatedAt: new Date().toISOString(),
      });
      logger.info('plan.narratives.generated', {
        planId: plan.id,
        weeks: parsed.weeks.length,
      });
    } catch (err) {
      logger.warn('plan.narratives.failed', {
        planId: plan.id,
        err: err instanceof Error ? err.message : String(err),
      });
    }
  }

  private _parseNarrativesJson(raw: string): { mesocycle: string; weeks: { weekNumber: number; narrative: string }[] } | null {
    try {
      // Strip fenced code blocks se vierem
      const cleaned = raw.replace(/^```(?:json)?\s*|\s*```\s*$/g, '').trim();
      const start = cleaned.indexOf('{');
      const end = cleaned.lastIndexOf('}');
      if (start < 0 || end <= start) return null;
      const json = cleaned.slice(start, end + 1);
      const obj = JSON.parse(json) as { mesocycle?: unknown; weeks?: unknown };
      if (typeof obj.mesocycle !== 'string') return null;
      if (!Array.isArray(obj.weeks)) return null;
      const weeks = obj.weeks.filter((x): x is { weekNumber: number; narrative: string } => {
        return !!x && typeof (x as { weekNumber?: unknown }).weekNumber === 'number'
          && typeof (x as { narrative?: unknown }).narrative === 'string';
      });
      return { mesocycle: obj.mesocycle, weeks };
    } catch {
      return null;
    }
  }

  private _dowName(d: number): string {
    const i = Math.max(1, Math.min(7, d));
    return ['', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'][i] ?? '?';
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

    // Week 1 só conta dias a partir de HOJE. Se a IA agendou sessão pra
    // segunda e o user gerou na quarta, a sessão de segunda é descartada
    // (em vez de aparecer como "perdida" no app).
    // Mon=1...Sun=7 (Date.getDay() retorna 0=Sun → tratamos como 7).
    const todayDow = new Date().getDay() || 7;

    return parsed.map((week, weekIndex) => {
      const allSessions = week.sessions.map(session => ({
        id: uuid(),
        dayOfWeek: session.dayOfWeek,
        type: session.type,
        distanceKm: Number(session.distanceKm.toFixed(1)),
        targetPace: session.targetPace,
        notes: session.notes,
      }) satisfies PlanSession);

      const filtered = weekIndex === 0
        ? allSessions.filter(s => s.dayOfWeek >= todayDow)
        : allSessions;

      return {
        weekNumber: week.weekNumber || weekIndex + 1,
        sessions: filtered.sort((a, b) => {
          if (a.dayOfWeek !== b.dayOfWeek) return a.dayOfWeek - b.dayOfWeek;
          return a.id.localeCompare(b.id);
        }),
      };
    });
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

export function resolvePlanWeeksCount(input: Pick<GeneratePlanInput, 'goal' | 'level' | 'frequency'>): number {
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
