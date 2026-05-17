import { v4 as uuid } from 'uuid';
import { z } from 'zod';
import { getAsyncLLM } from '@shared/infra/llm/llm.factory';
import { PlanRepository } from '../domain/plan.repository';
import { Plan, PlanSegment, PlanSession, PlanWeek } from '../domain/plan.entity';
import { buildExecutionSegments } from './build-execution-segments';
import { ScheduleCheckpointsUseCase } from './schedule-checkpoints.use-case';
import { FirestorePlanCheckpointRepository } from '../infra/firestore-plan-checkpoint.repository';
import { logger } from '@shared/logger/logger';
import { formatRunningKnowledgeContext } from '@shared/knowledge/running/running-knowledge';
import { buildPlanInitPrompt } from '@shared/infra/llm/prompts';
import { CoachRuntimeContextService } from '@modules/coach/use-cases/coach-runtime-context.service';
import { container } from '@shared/container';
import { CooldownError } from '@shared/errors/app-error';

const PlanSegmentSchema = z.object({
  kmStart: z.number().nonnegative(),
  kmEnd: z.number().positive(),
  phase: z.string().min(1),
  targetPace: z.string().min(1).optional(),
  durationMin: z.number().positive().max(120).optional(),
  instruction: z.string().min(1).max(500),
});

const PlanSessionSchema = z.object({
  dayOfWeek: z.number().int().min(1).max(7),
  type: z.string().min(1),
  distanceKm: z.number().positive().max(60),
  targetPace: z.string().min(1).optional(),
  durationMin: z.number().positive().max(600).optional(),
  hydrationLiters: z.number().positive().max(10).optional(),
  nutritionPre: z.string().max(400).optional(),
  nutritionPost: z.string().max(400).optional(),
  executionSegments: z.array(PlanSegmentSchema).max(20).optional(),
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
  /**
   * Data D0 escolhida pelo atleta no onboarding (ISO YYYY-MM-DD).
   * Se ausente, default = hoje. Plano e periodização começam nessa data.
   */
  startDate: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, 'startDate deve ser YYYY-MM-DD')
    .optional(),
});

export type GeneratePlanInput = z.infer<typeof GeneratePlanSchema>;

export class GeneratePlanUseCase {
  private llm = getAsyncLLM();
  private runtime = new CoachRuntimeContextService();
  // Default impl injetada via construtor de classe pra não exigir DI
  // explícita no callsite, mas trocável em testes.
  private scheduleCheckpoints = new ScheduleCheckpointsUseCase(
    new FirestorePlanCheckpointRepository(),
  );

  constructor(private repo: PlanRepository) {}

  async execute(userId: string, input: GeneratePlanInput, opts: { confirmOverwrite?: boolean } = {}): Promise<Plan> {
    // Guard CRÍTICO: plano requer onboarding completo. Sem isso o LLM
    // não tem dados pra personalizar (cai em template genérico) — e
    // user perde a percepção de "plano feito pra mim".
    const profile = await container.repos.users.findById(userId);
    if (!profile?.onboarded) {
      const err = new Error('Onboarding incompleto. Termine o onboarding antes de gerar o plano.');
      (err as Error & { code?: string }).code = 'ONBOARDING_REQUIRED';
      throw err;
    }
    const missingCritical: string[] = [];
    if (!profile.goal) missingCritical.push('objetivo');
    if (!profile.level) missingCritical.push('nível');
    if (!profile.birthDate) missingCritical.push('data de nascimento');
    if (!profile.weight) missingCritical.push('peso');
    if (!profile.height) missingCritical.push('altura');
    if (missingCritical.length > 0) {
      const err = new Error(`Onboarding incompleto: faltam ${missingCritical.join(', ')}.`);
      (err as Error & { code?: string }).code = 'ONBOARDING_INCOMPLETE';
      throw err;
    }

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

    // startDate vem do onboarding (último step "quando começar"). Aceita
    // qualquer data futura (ou hoje). Sem ela, default = hoje.
    const startDate = input.startDate ?? new Date().toISOString().slice(0, 10);

    // Cria o plano como "generating" imediatamente
    const plan: Plan = {
      id: planId,
      userId,
      goal: input.goal,
      level: input.level,
      weeksCount,
      status: 'generating',
      weeks: [],
      startDate,
      createdAt: now,
      updatedAt: now,
    };
    await this.repo.create(plan);

    // Gera o plano em background
    this._generateAsync(plan, { ...input, weeksCount, startDate }).catch(err =>
      logger.error('plan.generate.background_failed', {
        planId,
        err: err instanceof Error ? err.message : String(err),
      }),
    );

    return plan;
  }

  private async _generateAsync(
    plan: Plan,
    input: GeneratePlanInput & { weeksCount: number; startDate: string },
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
      input: { goal: input.goal, level: input.level, frequency: freq, weeksCount: input.weeksCount, startDate: input.startDate },
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
      const parsedWeeks = await this._parseWeeks(raw, input.weeksCount, input.startDate);
      // Frequency enforcement: o LLM ocasionalmente devolve 1 sessão/sem
      // mesmo com freq=5 (sub-prompt frouxo ou bias defensivo). Preenchemos
      // determinísticamente com Easy Run em dias livres até bater freq.
      const weeks = this._padToFrequency(parsedWeeks, freq, input.startDate);
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
      // Cria 1 checkpoint por semana (fire-and-forget). Idempotente.
      void this.scheduleCheckpoints
        .execute({ ...plan, weeks, status: 'ready' })
        .catch((err) =>
          logger.warn('plan.checkpoints.schedule_failed', {
            planId: plan.id,
            err: err instanceof Error ? err.message : String(err),
          }),
        );
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

      const userPrompt = `Você é o Coach AI do runnin. Escreva o RACIONAL do plano (markdown, 1000-1400 palavras — equilíbrio entre objetivo e detalhe suficiente pro atleta confiar). Vai ser renderizado em seções colapsáveis no app.

REGRA DE OURO: cada seção deve dar AO MENOS 2-3 parágrafos densos OU 4-6 bullets detalhados. Sem enrolação, mas COM substância — o atleta precisa SENTIR que o coach explicou as decisões. Frases de 1 linha só pra seções genuinamente curtas (ex: "Limites"). NUNCA repita ideias entre seções.

# Dados do atleta considerados
${profileLines}

# Plano gerado
- Objetivo: ${plan.goal} / Nível: ${plan.level} / Duração: ${plan.weeksCount} semanas / Volume total: ${totalKm.toFixed(1)}km

${sessionsBySection}

ESTRUTURA OBRIGATÓRIA (use exatamente esses ## headings):

## Avaliação do objetivo
2-3 parágrafos densos. Se o objetivo é desproporcional, diga direto e cite quanto tempo realista (meses) seria necessário pra chegar lá. Cite o método (Lydiard/Daniels/Maffetone/Polarized 80-20) escolhido em 1-2 frases, explicando o PRINCÍPIO central — por que esse método combina com este perfil específico.

## Leitura do perfil (verificações + ajustes)
Parágrafo introdutório de 1-2 linhas: "Antes de montar, verifiquei: ..." listando os campos chave que considerei. Em seguida 4-6 bullets DENSOS, formato OBRIGATÓRIO: "Verifiquei que [DADO COM VALOR] → [AJUSTE EXPLÍCITO + razão fisiológica/clínica em 1 frase]". Exemplos do tom esperado:
- "Verifiquei que você tem hipertensão e toma betabloqueador → reduzi intensidade em Z3 pra Z2 e tirei intervalado das 3 primeiras semanas. Beta bloqueia adrenalina e baixa o teto de FC, então suas zonas vão parecer baixas mas estão certas pro seu coração medicado."
- "Verifiquei que você teve cirurgia recente no tendão de Aquiles → eliminei subidas e dei prioridade pra Easy Run em piso plano nas primeiras 6 semanas. Tendão regenerado precisa de carga constante de baixo impacto antes de aceitar variação."
- "Verifiquei que você acorda 06:00 e prefere correr de manhã → marquei sessões duras 06:30-07:30, cortisol alto, gap de 2h pro almoço."
Se um campo está vazio, NÃO mencione.

## Periodização semana a semana
Liste EXATAMENTE ${plan.weeksCount} bullets, NEM 1 A MAIS. Formato: "**Semana N (FASE)** — volume Xkm. Objetivo específico em 1-2 frases conectando com a semana anterior/próxima". Pare na semana ${plan.weeksCount}. NÃO escreva "...continua". Demonstre como a progressão se constrói (incremento %, deload, transição base→build→peak→taper).

## Tipos de sessão neste plano
Para cada tipo PRESENTE neste plano (cheque o sessionsBySection acima — se Intervalado/Tempo não aparece, NÃO mencione), 2-3 linhas explicando o estímulo fisiológico (mitocôndrias, limiar lático, VO2max, economia de corrida) e onde aparece no plano + por quê dessa quantidade. Máximo 4 tipos.

## Recomendações específicas
5-6 bullets ESPECÍFICAS ao perfil deste atleta — cada um com VALOR real (não genérico):
- alimentação considerando peso/objetivo + 1 exemplo de refeição.
- hidratação: peso × 0.035L com cap em 3.5L (valor calculado pro atleta).
- recuperação considerando idade (mais velho = sono+alongamento crítico).
- sinais de alerta considerando condições médicas (cite quais).
- dica de horário considerando wakeTime/sleepTime/runPeriod (concreto).

## Como vou adaptar o plano
2 parágrafos. Explique:
- Por corrida: ajusto pace/volume da próxima sessão se BPM/pace ficar fora do esperado.
- Por semana (cron semanal): reviso aderência + reduzo carga se você falhar 2+ sessões seguidas.
- Por evento extraordinário: novo exame OCR, lesão reportada, mudança de objetivo → replan imediato.

## Limites deste plano
3-4 bullets transparentes: o que este plano NÃO promete, o que precisa de wearable/exames pra melhorar, riscos a ter ciência (ex: "não vou prescrever HIIT até semana 4 mesmo se você se sentir pronto, porque seu BMI ainda exige base aeróbica longa").

REGRAS GERAIS:
- NUNCA invente dados ausentes.
- "você" sempre.
- Sem emojis.
- Se a seção for redundante com outra, encurte. Não repita.
- Pare EXATAMENTE na semana ${plan.weeksCount}; não invente semanas extras.`;

      const raw = await this.llm.generate(userPrompt, {
        systemPrompt: 'Você é o Coach AI do runnin. Tom: técnico, direto, sem prolixidade. Cada parágrafo pesa. Sem emojis. PT-BR.',
        maxTokens: 3000,
        temperature: 0.35,
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
        maxTokens: 3000,
        temperature: 0.4,
      });

      const parsed = this._parseNarrativesJson(raw);
      if (!parsed) return;

      // Dedupe + clamp: garante 1 narrativa por week.weekNumber, sem
      // narrativas repetidas. Se o LLM cuspiu menos narrativas, as faltantes
      // ficam com narrative=undefined (UI lida com isso). Se cuspiu mais,
      // ignoramos os excedentes.
      const seenWeeks = new Set<number>();
      const uniqueNarratives = parsed.weeks.filter(x => {
        if (x.weekNumber > weeks.length || x.weekNumber < 1) return false;
        if (seenWeeks.has(x.weekNumber)) return false;
        seenWeeks.add(x.weekNumber);
        return true;
      });

      const enriched: PlanWeek[] = weeks.map((w) => {
        const match = uniqueNarratives.find((x) => x.weekNumber === w.weekNumber);
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

  private async _parseWeeks(raw: string, weeksCount: number, startDate: string): Promise<PlanWeek[]> {
    try {
      const normalized = this._normalizeWeeks(raw, startDate);
      return this._ensureWeeksCount(normalized, weeksCount, startDate);
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
        const normalized = this._normalizeWeeks(repaired, startDate);
        return this._ensureWeeksCount(normalized, weeksCount, startDate);
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

        const normalized = this._normalizeWeeks(repairedAgain, startDate);
        return this._ensureWeeksCount(normalized, weeksCount, startDate);
      }
    }
  }

  /**
   * Garante que cada semana tem pelo menos `targetFreq` sessões. Quando
   * o LLM devolve menos (bug recorrente: pede 5x, devolve 1x), preenche
   * com Easy Run em dias livres da semana. Distância clonada da média
   * das sessões existentes (ou padrão por nível se semana vazia).
   *
   * Exceção: semana 1 pode ter menos sessões quando D0 cai já no meio
   * da semana — não força preenchimento em dias anteriores ao D0.
   */
  private _padToFrequency(
    weeks: PlanWeek[],
    targetFreq: number,
    startDate: string,
  ): PlanWeek[] {
    const start = new Date(`${startDate}T00:00:00`);
    const startDow = start.getDay() || 7;
    let totalPadded = 0;
    const padded = weeks.map((w, idx) => {
      // Semana 1: cap em (8 - startDow) sessões possíveis (D0 → domingo)
      const maxAllowed = idx === 0 ? Math.min(targetFreq, 8 - startDow) : targetFreq;
      if (w.sessions.length >= maxAllowed) return w;

      const occupiedDays = new Set(w.sessions.map((s) => s.dayOfWeek));
      const dowMin = idx === 0 ? startDow : 1;
      const freeDays: number[] = [];
      for (let d = dowMin; d <= 7; d++) {
        if (!occupiedDays.has(d)) freeDays.push(d);
      }
      // Distribui dias com gaps (evita 3 dias seguidos).
      freeDays.sort((a, b) => a - b);

      const avgDistance = w.sessions.length > 0
        ? w.sessions.reduce((s, x) => s + x.distanceKm, 0) / w.sessions.length
        : 4;
      const padDistanceKm = Number(Math.max(3, Math.min(8, avgDistance)).toFixed(1));

      const needed = maxAllowed - w.sessions.length;
      const newSessions: PlanSession[] = [];
      for (let i = 0; i < needed && i < freeDays.length; i++) {
        const dow = freeDays[i]!;
        const base = {
          id: uuid(),
          dayOfWeek: dow,
          type: 'Easy Run',
          distanceKm: padDistanceKm,
          notes: `[BASE] Sessão preenchida automaticamente pra atingir frequência alvo de ${targetFreq}x/semana. Easy run conversável.`,
        } satisfies Omit<PlanSession, 'executionSegments' | 'targetPace' | 'durationMin' | 'hydrationLiters' | 'nutritionPre' | 'nutritionPost'>;
        const segs = buildExecutionSegments(base as PlanSession);
        newSessions.push({ ...base, executionSegments: segs } satisfies PlanSession);
        totalPadded++;
      }
      const combined = [...w.sessions, ...newSessions].sort((a, b) => {
        if (a.dayOfWeek !== b.dayOfWeek) return a.dayOfWeek - b.dayOfWeek;
        return a.id.localeCompare(b.id);
      });
      return { ...w, sessions: combined };
    });

    if (totalPadded > 0) {
      logger.warn('plan.parse.frequency_padded', {
        targetFreq,
        totalPadded,
        countsBefore: weeks.map((w) => w.sessions.length),
        countsAfter: padded.map((w) => w.sessions.length),
      });
    }
    return padded;
  }

  private _normalizeWeeks(raw: string, startDate: string): PlanWeek[] {
    const parsedJson = this._parseJsonLenient(raw);
    // Parse tolerante: descarta sessions inválidas (campos undefined/null)
    // ao invés de invalidar o array inteiro. Gemini ocasionalmente omite
    // dayOfWeek/type/distanceKm em 1-2 sessions; antes isso fazia
    // PlanWeeksSchema.parse() rejeitar TUDO e o user ficar com plano falso.
    const candidate = this._extractWeeksCandidate(parsedJson);
    const lenientWeeks = this._coerceWeeksLenient(candidate);
    const parsed = PlanWeeksSchema.parse(lenientWeeks);

    // Week 1 filtra sessões com dayOfWeek < startDayOfWeek (D0 escolhido
    // pelo user no onboarding). Sem fallback "manter tudo" — o prompt
    // já instrui a IA a respeitar isso. Mon=1...Sun=7.
    const start = new Date(`${startDate}T00:00:00`);
    const startDow = (start.getDay() || 7);

    const normalized = parsed.map((week, weekIndex) => {
      const allSessions = week.sessions.map(session => {
        const base = {
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
        } satisfies Omit<PlanSession, 'executionSegments'>;
        // Segments: prioriza o que LLM mandou (caso futuro o prompt
        // volte a pedir), senão gera deterministicamente a partir de
        // distância + tipo + pace. Sem LLM, instantâneo.
        const segments: PlanSegment[] | undefined =
          (session.executionSegments?.length ?? 0) > 0
            ? (session.executionSegments as PlanSegment[])
            : buildExecutionSegments(base);
        return { ...base, executionSegments: segments } satisfies PlanSession;
      });

      // Week 1: descarta SEMPRE sessões com dayOfWeek < hoje (LLM não deveria
      // ter gerado, mas garante). Não há fallback "manter tudo" — sessão
      // passada na week 1 confunde o usuário (parece que o plano "atrasou").
      // Se week 1 ficar vazia, paciência: o usuário começa a sério no
      // próximo dia. O prompt foi instruído a evitar isso.
      const filtered = weekIndex === 0
        ? allSessions.filter(s => s.dayOfWeek >= startDow)
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
        // Sanitiza executionSegments: descarta segments inválidos sem
        // invalidar a session inteira. LLM pode omitir campos.
        if (Array.isArray(cleaned.executionSegments)) {
          const segs = (cleaned.executionSegments as unknown[])
            .filter((seg): seg is Record<string, unknown> => !!seg && typeof seg === 'object')
            .map((seg) => {
              const s = { ...seg } as Record<string, unknown>;
              const kmStartOk = typeof s.kmStart === 'number' && s.kmStart >= 0;
              const kmEndOk = typeof s.kmEnd === 'number' && s.kmEnd > 0;
              const phaseOk = typeof s.phase === 'string' && s.phase.trim().length > 0;
              const instOk = typeof s.instruction === 'string' && s.instruction.trim().length > 0;
              if (!kmStartOk || !kmEndOk || !phaseOk || !instOk) return null;
              if (typeof s.durationMin !== 'number' || s.durationMin <= 0) delete s.durationMin;
              if (typeof s.targetPace !== 'string' || !s.targetPace.trim()) delete s.targetPace;
              return s;
            })
            .filter((s): s is Record<string, unknown> => s !== null);
          if (segs.length === 0) delete cleaned.executionSegments;
          else cleaned.executionSegments = segs;
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

  private async _ensureWeeksCount(weeks: PlanWeek[], weeksCount: number, startDate: string): Promise<PlanWeek[]> {
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

    const rebalanced = this._normalizeWeeks(rebalancedRaw, startDate);
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
    // Rotação de tipos pra evitar clones idênticos quando o LLM truncou.
    // Cada nova semana intercala intensidade/tipo de qualidade.
    const qualityRotation = ['Tempo Run', 'Intervalado', 'Long Run'];
    while (result.length < weeksCount) {
      const source = result[result.length - 1];
      if (!source) break;

      const nextWeekNumber = result.length + 1;
      const isRecoveryWeek = nextWeekNumber % 4 === 0;
      const progressionFactor = isRecoveryWeek ? 0.85 : 1.05;
      const rotationKey = qualityRotation[(nextWeekNumber - 1) % qualityRotation.length] ?? 'Tempo Run';

      // Substitui APENAS a primeira "Easy Run" da semana clonada pelo
      // tipo de qualidade rotacionado — força mínimo de variação entre
      // semanas (evita 5 semanas idênticas após o último parsed).
      let qualitySwapped = false;
      const newSessions = source.sessions.map((session, idx) => {
        const newSession = {
          ...session,
          id: uuid(),
          distanceKm: Number(Math.max(1, session.distanceKm * progressionFactor).toFixed(1)),
          notes: this._deriveExpandedWeekNotes(session.notes, nextWeekNumber, isRecoveryWeek),
        };
        if (!qualitySwapped && !isRecoveryWeek &&
            session.type.toLowerCase().includes('easy') &&
            idx === Math.floor(source.sessions.length / 2)) {
          newSession.type = rotationKey;
          newSession.notes = `[BUILD] ${rotationKey} pra estimular novo sistema energético na semana ${nextWeekNumber}. ${newSession.notes}`;
          qualitySwapped = true;
        }
        return newSession;
      });

      result.push({
        weekNumber: nextWeekNumber,
        sessions: newSessions,
        focus: isRecoveryWeek ? 'Recuperação ativa' : `Build (${rotationKey})`,
        narrative: isRecoveryWeek
          ? `[DELOAD] Semana ${nextWeekNumber} reduz volume em ~15% pra absorver o trabalho. Foco em recuperação, alongamento e sono.`
          : `[BUILD] Semana ${nextWeekNumber} introduz ${rotationKey} pra subir o estímulo de qualidade. Mantenha aderência e respeito ao plano.`,
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
