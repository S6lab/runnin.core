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
  durationMin: z.number().positive().max(600).optional(),
  hydrationLiters: z.number().positive().max(10).optional(),
  nutritionPre: z.string().max(400).optional(),
  nutritionPost: z.string().max(400).optional(),
  notes: z.string().default(''),
});

const PlanRestDayTipSchema = z.object({
  dayOfWeek: z.number().int().min(1).max(7),
  hydrationLiters: z.number().positive().max(10).optional(),
  nutrition: z.string().max(400).optional(),
  focus: z.string().max(120).optional(),
});

const PlanWeekSchema = z.object({
  weekNumber: z.number().int().min(1),
  sessions: z.array(PlanSessionSchema).max(7),
  restDayTips: z.array(PlanRestDayTipSchema).max(7).optional(),
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
            `- Janela do dia: acorda ${profile.wakeTime ?? '—'} / dorme ${profile.sleepTime ?? '—'}`,
            `- Idade: ${profile.birthDate ?? '—'}`,
            `- Peso: ${profile.weight ?? '—'} | Altura: ${profile.height ?? '—'}`,
            `- FC repouso: ${profile.restingBpm ?? '—'} | FC máx: ${profile.maxBpm ?? '—'}`,
            `- Condições médicas: ${(profile.medicalConditions ?? []).join(', ') || 'nenhuma'}`,
            `- Wearable conectado: ${profile.hasWearable ? 'sim' : 'não'}`,
            `- Persona do coach: ${profile.coachPersonality ?? 'motivador'}`,
          ].join('\n')
        : '(perfil não disponível)';

      const userPrompt = `Você é o Coach AI do runnin. Escreva uma explicação DETALHADA, HONESTA E CRÍTICA (markdown, 1200-1800 palavras) sobre o plano que VOCÊ acabou de gerar.

Este texto é o que garante o atleta confiar no plano: ele precisa SENTIR que o coach pensou nele especificamente, com critério metodológico, transparência sobre limites, e visão clara de como o plano vai evoluir.

# Dados do atleta considerados
${profileLines}

# Plano gerado
- Objetivo declarado: ${plan.goal}
- Nível declarado: ${plan.level}
- Duração: ${plan.weeksCount} semanas
- Volume total: ${totalKm.toFixed(1)}km

${sessionsBySection}

Estrutura esperada do markdown (use ##/### headings, parágrafos de verdade):

## Avaliação realista do seu objetivo
2-3 parágrafos. Aqui você é HONESTO. Se o objetivo declarado é desproporcional ao nível atual (ex: iniciante quer ultra), diga claramente que este plano de ${plan.weeksCount} semanas é a FASE DE FUNDAÇÃO — e quanto tempo realista (em meses) levaria pra chegar no objetivo final. Cite literatura/método (Lydiard, Daniels, Maffetone, Pfitzinger) quando for relevante pra justificar a decisão. Se objetivo está alinhado ao nível, valide com critério.

## Como li o seu perfil
OBRIGATÓRIO citar EXPLICITAMENTE cada dado relevante do atleta neste formato: "verifiquei que você tem X, então fiz Y". Use o NOME do dado e do ajuste.

Parágrafo introdutório curto começando com "Antes de montar o plano, verifiquei tudo que você me passou: ..." listando os campos chave que você considerou (idade, gênero, peso, altura, BPM repouso/máx se houver, condições médicas TODAS pelo nome, wearable, horários de acordar/dormir, janela do dia).

Em seguida, 5-8 bullets DENSOS no formato "verifiquei que [DADO ESPECÍFICO COM VALOR] → [AJUSTE EXPLÍCITO QUE FIZ NO PLANO]". Exemplos do tom esperado:
- "Verifiquei que você tem hipertensão e toma betabloqueador → reduzi intensidade em Z3 pra Z2 e tirei intervalado das 3 primeiras semanas. Suas zonas de FC vão parecer baixas mas são corretas pro seu coração medicado. Comecei mais leve pra eu poder monitorar seu desempenho nas primeiras sessões."
- "Verifiquei que você teve cirurgia recente no tendão de Aquiles → eliminei subidas e dei prioridade pra Easy Run em piso plano nas primeiras 6 semanas; vou liberar terreno variado só na semana 7."
- "Verifiquei que você tem 43 anos e BMI 27.1 → a progressão semanal vai em incrementos de 8% (não 10%) e incluí um deload na semana 4 mais profundo."
- "Verifiquei que você acorda 06:00 e dorme 23:00, prefere correr de manhã → marquei sessões mais exigentes 06:30-07:30 (cortisol alto, gap de 2h pro almoço)."
NUNCA bullets genéricos. Se um campo está vazio, NÃO mencione.

## Metodologia que escolhi pra você
2-3 parágrafos explicando QUAL método de treino estruturou este plano (periodização linear 3:1, base aeróbica de Lydiard, polarized 80/20, MAF de Maffetone, etc.) e POR QUE esse método combina com SEU perfil + objetivo. Cite o nome do método, princípio central, e tradução prática pro que ele vai sentir.

## Periodização semana a semana
Tabela mental detalhada — liste TODAS as semanas com FASE + objetivo + carga estimada:
- **Semana 1 (FASE_NOME)** — Volume Xkm. Objetivo: ...
- **Semana 2 (FASE_NOME)** — Volume Xkm. Objetivo: ...
- ... (continua até Semana ${plan.weeksCount})
Cada semana é CONSEQUÊNCIA da anterior. Explique a lógica de progressão (incremento %, ciclo de deload, transição base→specific→peak→taper).

## O que cada tipo de sessão faz no seu corpo
3-4 parágrafos breves. Para cada tipo de treino presente no plano (Easy Run, Long Run, Tempo, Intervalado, Cross), explique o estímulo fisiológico (mitocôndrias, limiar lático, VO2max, economia de corrida) e onde no plano ele aparece e por quê.

## Recomendações específicas pra você
5-7 bullets de ações ESPECÍFICAS — alimentação considerando peso/objetivo, hidratação considerando peso × 0.035L, recuperação considerando idade, sinais de alerta considerando condições médicas, dica de horário considerando wakeTime/sleepTime/runPeriod. Nada genérico.

## Como vou adaptar o seu plano
2 parágrafos. Explique o sistema de adaptação:
- A cada CORRIDA CONCLUÍDA: ajusto volume/pace da próxima sessão se BPM ou pace ficou fora do esperado.
- A cada SEMANA COMPLETA: reviso a semana seguinte considerando aderência, recuperação, lesões reportadas e novos exames carregados.
- A cada FALHA RECORRENTE (2 sessões seguidas perdidas): reduzo carga automaticamente e te mando alerta.
Mensagem realista: o plano NÃO é estático.

## O que NÃO vou fazer
3-4 bullets de transparência sobre LIMITES — o que este plano não promete, o que ainda precisa de wearable/exames pra melhorar, riscos que você precisa ter ciência (ex: "não vou prescrever HIIT até semana 4 mesmo se você se sentir pronto, porque seu BMI ainda exige base aeróbica longa primeiro").

REGRAS:
- NUNCA invente dados que não estão no perfil. Se um campo está vazio, ignore (não escreva "FC máx: não informado").
- Use "você" pra falar com o atleta.
- Não use emojis.
- Linguagem técnica + acessível. Não simplifica demais — o atleta quer SENTIR que você sabe do que está falando.
- Seja crítico onde precisa ser. Se o objetivo é irrealista, diga sem rodeios. Não infle expectativa.`;

      const raw = await this.llm.generate(userPrompt, {
        systemPrompt: 'Você é o Coach AI do runnin. Tom: confiante, técnico mas acessível. Profundidade > brevidade. Não use emojis. Português BR.',
        maxTokens: 4000,
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

      const userPrompt = `Você é o Coach AI do runnin. Produza narrativas curtas, personalizadas e CONECTADAS entre si. Cada semana é uma peça de uma jornada — explicite a fase e a relação com a anterior/próxima.

Responda APENAS JSON estritamente neste schema:

{
  "mesocycle": "string (3-5 frases). Explique: (1) avaliação realista do gap nível-vs-objetivo (se objetivo é ambicioso pro nível, diga que essas ${plan.weeksCount} semanas são fundação, NÃO o objetivo final); (2) estratégia de periodização (padrão 3:1, deload, blocos); (3) o que ele DEVE esperar ao final dessas semanas (resultado realista).",
  "weeks": [
    {
      "weekNumber": 1,
      "narrative": "string (2-3 frases). DEVE COMEÇAR com a FASE em colchetes (ex: '[BASE]', '[BUILD]', '[DELOAD]', '[SPECIFIC]', '[PEAK]', '[TAPER]'). Em seguida: foco da semana + sessão-chave + conexão com a próxima ou anterior ('preparamos pra...' / 'consolida o que fez na semana X')."
    },
    ...
  ]
}

REGRAS CRÍTICAS:
- weeks tem EXATAMENTE ${weeks.length} elementos (1 por semana).
- A FASE de cada semana SAI do volume relativo: se volume cai 30%+ da semana anterior = DELOAD/TAPER; se mantém com qualidade nova = BUILD; se sobe sem qualidade = BASE+; semana de início (S1) = BASE; última = TAPER ou PEAK conforme objetivo.
- Mesociclo precisa fazer leitura HONESTA do gap nível→objetivo (não infle expectativa).
- Cada narrative deve EXPLICITAMENTE conectar com a sequência (não pode ser independente).
- Sem emojis, sem markdown, "você", PT-BR.

${profileLine}

Estrutura do plano (use volume/qualidade pra inferir a fase de cada semana):
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
    // Parse tolerante: descarta sessions inválidas (campos undefined/null)
    // ao invés de invalidar o array inteiro. Gemini ocasionalmente omite
    // dayOfWeek/type/distanceKm em 1-2 sessions; antes isso fazia
    // PlanWeeksSchema.parse() rejeitar TUDO e o user ficar com plano falso.
    const candidate = this._extractWeeksCandidate(parsedJson);
    const lenientWeeks = this._coerceWeeksLenient(candidate);
    const parsed = PlanWeeksSchema.parse(lenientWeeks);

    // Week 1 prioriza dias ≥ hoje. Se isso esvazia a semana inteira (caso
    // típico: user gera no fim de semana e a IA não pôs sessão pra hoje),
    // mantém todas as sessões pra não entregar semana vazia. O app exibe
    // sessões passadas como "perdidas" — melhor que nenhuma sessão.
    // Mon=1...Sun=7 (Date.getDay() retorna 0=Sun → tratamos como 7).
    const todayDow = new Date().getDay() || 7;

    const normalized = parsed.map((week, weekIndex) => {
      const allSessions = week.sessions.map(session => ({
        id: uuid(),
        dayOfWeek: session.dayOfWeek,
        type: session.type,
        distanceKm: Number(session.distanceKm.toFixed(1)),
        targetPace: session.targetPace,
        durationMin: session.durationMin,
        hydrationLiters: session.hydrationLiters,
        nutritionPre: session.nutritionPre,
        nutritionPost: session.nutritionPost,
        notes: session.notes,
      }) satisfies PlanSession);

      // Week 1: descarta SEMPRE sessões com dayOfWeek < hoje (LLM não deveria
      // ter gerado, mas garante). Não há fallback "manter tudo" — sessão
      // passada na week 1 confunde o usuário (parece que o plano "atrasou").
      // Se week 1 ficar vazia, paciência: o usuário começa a sério no
      // próximo dia. O prompt foi instruído a evitar isso.
      const filtered = weekIndex === 0
        ? allSessions.filter(s => s.dayOfWeek >= todayDow)
        : allSessions;

      return {
        weekNumber: week.weekNumber || weekIndex + 1,
        sessions: filtered.sort((a, b) => {
          if (a.dayOfWeek !== b.dayOfWeek) return a.dayOfWeek - b.dayOfWeek;
          return a.id.localeCompare(b.id);
        }),
        restDayTips: week.restDayTips,
      };
    });

    const totalSessions = normalized.reduce(
      (sum, w) => sum + w.sessions.length,
      0,
    );
    if (totalSessions === 0) {
      // Plano com 0 sessões no total é parse failure mascarado (LLM
      // devolveu weeks com sessions: []). Joga pro retry/repair loop em
      // vez de salvar plano vazio no Firestore.
      throw new Error(
        `Plan parsed with 0 total sessions across ${normalized.length} weeks — treating as parse failure`,
      );
    }

    return normalized;
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

  /**
   * Filtra sessions com campos obrigatórios faltando (dayOfWeek, type,
   * distanceKm). Gemini ocasionalmente devolve sessions com `undefined`
   * em algum campo crítico; antes isso fazia o array INTEIRO ser
   * rejeitado pelo schema. Agora descartamos só a session quebrada e
   * mantemos o resto da semana.
   */
  private _coerceWeeksLenient(value: unknown): unknown {
    if (!Array.isArray(value)) return value;
    let dropped = 0;
    const coerced = value.map((rawWeek, weekIdx) => {
      if (!rawWeek || typeof rawWeek !== 'object') return rawWeek;
      const w = rawWeek as Record<string, unknown>;
      if (!Array.isArray(w.sessions)) return w;
      const validSessions = w.sessions.map(s => {
        if (!s || typeof s !== 'object') return null;
        const sess = s as Record<string, unknown>;
        const dayOk = typeof sess.dayOfWeek === 'number' &&
          sess.dayOfWeek >= 1 && sess.dayOfWeek <= 7;
        const typeOk = typeof sess.type === 'string' && sess.type.trim().length > 0;
        const distOk = typeof sess.distanceKm === 'number' && sess.distanceKm > 0;
        if (!dayOk || !typeOk || !distOk) return null;
        // Limpa campos opcionais malformados pra Zod não rejeitar.
        const cleaned: Record<string, unknown> = { ...sess };
        if (typeof cleaned.durationMin !== 'number' || cleaned.durationMin <= 0) {
          delete cleaned.durationMin;
        }
        if (typeof cleaned.hydrationLiters !== 'number' || cleaned.hydrationLiters <= 0) {
          delete cleaned.hydrationLiters;
        }
        if (typeof cleaned.nutritionPre !== 'string' || !cleaned.nutritionPre.trim()) {
          delete cleaned.nutritionPre;
        }
        if (typeof cleaned.nutritionPost !== 'string' || !cleaned.nutritionPost.trim()) {
          delete cleaned.nutritionPost;
        }
        if (typeof cleaned.targetPace !== 'string' || !cleaned.targetPace.trim()) {
          delete cleaned.targetPace;
        }
        return cleaned;
      }).filter((s): s is Record<string, unknown> => {
        if (s === null) {
          dropped++;
          return false;
        }
        return true;
      });

      // Limpa restDayTips opcional também
      if (Array.isArray(w.restDayTips)) {
        w.restDayTips = w.restDayTips
          .filter((t): t is Record<string, unknown> => !!t && typeof t === 'object')
          .map(t => {
            const tip = { ...t } as Record<string, unknown>;
            if (typeof tip.dayOfWeek !== 'number' || tip.dayOfWeek < 1 || tip.dayOfWeek > 7) {
              return null;
            }
            if (typeof tip.hydrationLiters !== 'number' || tip.hydrationLiters <= 0) {
              delete tip.hydrationLiters;
            }
            if (typeof tip.nutrition !== 'string' || !tip.nutrition.trim()) {
              delete tip.nutrition;
            }
            if (typeof tip.focus !== 'string' || !tip.focus.trim()) {
              delete tip.focus;
            }
            return tip;
          })
          .filter((t): t is Record<string, unknown> => t !== null);
      }
      if (dropped > 0 && validSessions.length === 0) {
        logger.warn('plan.parse.week_empty_after_lenient', {
          weekIndex: weekIdx,
          originalCount: w.sessions.length,
        });
      }
      return { ...w, sessions: validSessions };
    });
    if (dropped > 0) {
      logger.warn('plan.parse.sessions_dropped_lenient', { dropped });
    }
    return coerced;
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
