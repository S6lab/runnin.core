import { z } from 'zod';
import { getRealtimeLLM } from '@shared/infra/llm/llm.factory';
import { formatRunningKnowledgeContext } from '@shared/knowledge/running/running-knowledge';
import { GeminiLiveTtsService } from '@shared/infra/llm/gemini-live-tts.service';
import { buildLiveCoachPrompt, getKnobs, isInDndWindow } from '@shared/infra/llm/prompts';
import { CoachConfigService } from './coach-config.service';
import { CoachRuntimeContextService } from './coach-runtime-context.service';
import { CoachMessageLogRepository } from '../domain/coach-message-log.repository';
import { CoachMessageLog } from '../domain/coach-message-log.entity';
import { FirestoreCoachMessageLogRepository } from '../infra/firestore-coach-message-log.repository';
import { FirestoreUserRepository } from '@modules/users/infra/firestore-user.repository';
import { logger } from '@shared/logger/logger';
import { randomUUID } from 'crypto';

const OptionalNumberSchema = z.preprocess(
  value => value === null ? undefined : value,
  z.number().optional(),
);

export const CoachContextSchema = z.object({
  runId: z.string().optional(),
  event: z.enum([
    'pre_run',
    'km_reached',
    'km_split',
    'pace_alert',
    'motivation',
    'question',
    'start',
    'finish',
    'preview',
    // Eventos estruturais ligados ao executionSegments da PlanSession.
    // segment_start: cliente cruzou a fronteira pro próximo segmento.
    // segment_pace_off: pace desviou do alvo DESTE segmento (substitui
    //   pace_alert quando há plano com segments). Cooldown 60s no client.
    // segment_end: último ponto GPS dentro do segmento final.
    'segment_start',
    'segment_pace_off',
    'segment_end',
  ]),
  runType: z.string().optional(),
  // currentPaceMinKm / distanceM / elapsedS são contexto de corrida ativa.
  // Para event=preview (settings) ou question (chat fora de run), não
  // existem ainda — default 0 evita 422 de validação sem mudar a lógica
  // dos events de runtime que sempre preenchem esses campos.
  currentPaceMinKm: z.number().default(0),
  targetPaceMinKm: OptionalNumberSchema,
  targetDistance: z.string().optional(),
  distanceM: z.number().default(0),
  elapsedS: z.number().default(0),
  bpm: OptionalNumberSchema,
  kmReached: OptionalNumberSchema,
  /** Duração (s) do km que acabou de ser cruzado — não acumulado. Enviado
   *  pelo client em events km_reached/km_split. Coach usa pra reportar
   *  "1 km em X minutos" em vez de tempo total da corrida. */
  kmDurationS: OptionalNumberSchema,
  /** FC média (bpm) durante o km que acabou de ser cruzado. Cliente
   *  acumula amostras BPM por km e envia média no fechamento. */
  kmAvgBpm: OptionalNumberSchema,
  question: z.string().optional(),
  /** ID da voz pra preview (event=preview). Mapeia pra Charon/Aoede/Kore
   *  no GeminiLiveTtsService. */
  voiceId: z.string().optional(),
  /** ID da PlanSession que está sendo executada. Quando presente, server
   *  resolve a sessão via runtime.getContext(userId, planSessionId) e
   *  inclui briefing completo (notes, segments, nutrição) no contexto
   *  do LLM. Null = Free Run, contexto sem plano. */
  planSessionId: z.string().optional(),
  /** Índice (0-based) do segment ativo dentro da PlanSession. Setado
   *  pelo client em eventos segment_*. Server usa pra extrair o segment
   *  específico e referenciá-lo no prompt. */
  currentSegmentIndex: z.number().int().nonnegative().optional(),
});

export type CoachContext = z.infer<typeof CoachContextSchema>;

export interface CoachCueResponse {
  text: string;
  audioBase64?: string;
  audioMimeType?: string;
}

export interface CoachCueSkipped {
  skipped: true;
  reason: 'frequency' | 'dnd' | 'silent';
}

export type CoachGenerateResult = CoachCueResponse | CoachCueSkipped;

export function isCueSkipped(result: CoachGenerateResult): result is CoachCueSkipped {
  return (result as CoachCueSkipped).skipped === true;
}

// Eventos estruturais que merecem o contexto completo da PlanSession
// no prompt (notes, segments, nutrição). Eventos de "ruído" recebem só
// um sessionSummary curto pra evitar token bloat — 10+ cues/run × 300
// tokens vira custo perceptível e o LLM não precisa do briefing inteiro
// pra dizer "ritmo bom no km 5".
const STRUCTURAL_SESSION_EVENTS = new Set([
  'start',
  'finish',
  'pace_alert',
  'segment_start',
  'segment_pace_off',
  'segment_end',
]);

// TTL do cache de runtime context por (userId, runId). Durante uma run,
// profile/plano/recentRuns não mudam — basta refetchar quando começa
// nova run. 5min é folga suficiente até pro warmup mais lento sem
// guardar dados velhos entre execuções.
const RUNTIME_CACHE_TTL_MS = 5 * 60 * 1000;

interface CachedRuntime {
  expiresAt: number;
  // Cache armazena por planSessionId distinto — runs Free Run e planejadas
  // resolvem currentSession diferente mesmo dentro da mesma sessão de cache.
  byPlanSession: Map<string, import('./coach-runtime-context.service').CoachRuntimeContext>;
}

export class CoachMessageUseCase {
  private llm = getRealtimeLLM();
  // Gemini Live TTS é o source primário (mesmo motor do chat ao vivo).
  // ElevenLabs/Google ficam como fallbacks pra resiliência.
  private liveTts = new GeminiLiveTtsService();
  private config = new CoachConfigService();
  private runtime = new CoachRuntimeContextService();
  private messageLog: CoachMessageLogRepository = new FirestoreCoachMessageLogRepository();
  private runtimeCache = new Map<string, CachedRuntime>();

  async generate(ctx: CoachContext, userId: string): Promise<CoachGenerateResult> {
    // Preview de voz no settings: sample short text via Live TTS, sem
    // LLM nem runtime context. voiceId vem do request body.
    if (ctx.event === 'preview') {
      return this._generateVoicePreview(ctx);
    }
    // Saudação inicial = caminho leve. Sem LLM, sem RAG, sem runtime
    // context pesado — só template baseado em nome do user + tipo de
    // corrida. Salva ~10s no entry da run e elimina ponto de falha.
    if (ctx.event === 'start') {
      return this._generateLightweightStart(ctx, userId);
    }

    const [config, runtime, knobs] = await Promise.all([
      this.config.getConfig(),
      this._getCachedRuntime(userId, ctx.runId, ctx.planSessionId),
      getKnobs(),
    ]);

    const decision = applyDecisionLayer(ctx, runtime.profile, knobs);
    if (decision) return decision;

    const knowledgeContext = await formatRunningKnowledgeContext(
      `${runtime.profile?.goal ?? ''} ${runtime.profile?.level ?? ''} ${ctx.event} corrida ${ctx.runType ?? ''} pace ${ctx.targetPaceMinKm ?? ''} bpm ${ctx.bpm ?? ''} ${ctx.question ?? ''}`,
      2,
    );

    // Adaptive context: estruturais recebem briefing completo da sessão
    // (notes + segments + nutrição); ruído (km_reached/km_split/motivation)
    // recebe só sessionSummary curto pra economizar tokens sem perder
    // a referência ao plano do dia.
    const runtimeForPrompt = STRUCTURAL_SESSION_EVENTS.has(ctx.event)
      ? runtime
      : { ...runtime, currentSession: null };
    const sessionSummary = formatSessionSummary(runtime.currentSession);
    const currentSegment = pickSegment(runtime.currentSession, ctx.currentSegmentIndex);
    const runtimeContextJson = JSON.stringify(
      {
        ...runtimeForPrompt,
        // Sempre publica o sessionSummary, mesmo nos eventos compactos —
        // 1 linha não custa nada e mantém o LLM ciente do objetivo do dia.
        sessionSummary,
        currentSegment,
      },
      null,
      2,
    );

    // Enriquece ctx com derived fields (kmCalories MET-based + athleteName)
    // pro prompt do coach reportar "1 km em X min, Y cal, FC Z bpm" no
    // event km_reached. Calorias derivam de MET 9.8 (corrida moderada) ×
    // peso × tempoDoKm — mesma constante usada em CompleteRunUseCase.
    const ctxEnriched: typeof ctx & { kmCalories?: number; athleteName?: string } = { ...ctx };
    if (typeof ctx.kmDurationS === 'number' && ctx.kmDurationS > 0 && typeof runtime.profile?.weight === 'number') {
      const MET = 9.8;
      ctxEnriched.kmCalories = Math.round((MET * runtime.profile.weight * ctx.kmDurationS) / 3600);
    }
    if (runtime.profile?.name) {
      ctxEnriched.athleteName = runtime.profile.name.split(' ')[0]; // primeiro nome
    }

    const built = await buildLiveCoachPrompt({
      profile: runtime.profile,
      runtimeContextJson,
      ctx: ctxEnriched,
      ragContext: knowledgeContext,
    });

    const rawText = await this.llm.generate(built.userPrompt, {
      systemPrompt: built.systemPrompt,
      maxTokens: built.maxTokens,
      temperature: built.temperature,
    });
    const text = cleanCueText(rawText);
    let audio = null as { audioBase64: string; mimeType: string } | null;

    if (config.ttsEnabled) {
      // Voz ÚNICA: só Gemini Live (Charon). SEM fallback ElevenLabs/Google na
      // corrida — trocar de engine no meio gerava vozes diferentes ("dois
      // coaches"). Se o Live falhar, o cue vai só como texto (sem áudio).
      audio = await this.liveTts.synthesize(text, { voiceId: 'coach-bruno' });
    }

    if (ctx.runId && ctx.event !== 'question') {
      const log: CoachMessageLog = {
        id: randomUUID(),
        runId: ctx.runId,
        userId,
        author: 'coach',
        event: ctx.event,
        text,
        audioMimeType: audio?.mimeType,
        kmAtTime: ctx.kmReached ?? (ctx.distanceM / 1000),
        paceAtTime: ctx.currentPaceMinKm ? ctx.currentPaceMinKm.toFixed(2) : undefined,
        bpmAtTime: ctx.bpm,
        promptVersion: built.version,
        promptSource: built.source,
        createdAt: new Date().toISOString(),
      };
      this.messageLog.save(log).catch(err => {
        logger.warn('coach.message_log.save_failed', { runId: ctx.runId, err: String(err) });
      });
    }

    return {
      text,
      audioBase64: audio?.audioBase64,
      audioMimeType: audio?.mimeType,
    };
  }

  async listForRun(userId: string, runId: string): Promise<CoachMessageLog[]> {
    return this.messageLog.listByRun(userId, runId);
  }

  /**
   * Cache de runtime context por (userId, runId, planSessionId).
   * Durante uma run, profile/plano não mudam — refetch a cada cue
   * (8-12/run) custa Firestore reads desnecessários. TTL 5min cobre
   * runs longas sem virar dado velho entre execuções.
   *
   * Quando runId não é setado (questions, previews), pula cache —
   * são chamadas pontuais.
   */
  private async _getCachedRuntime(
    userId: string,
    runId: string | undefined,
    planSessionId: string | undefined,
  ): Promise<import('./coach-runtime-context.service').CoachRuntimeContext> {
    if (!runId) {
      return this.runtime.getContext(userId, planSessionId);
    }
    const key = `${userId}:${runId}`;
    const planKey = planSessionId ?? '__none__';
    const now = Date.now();
    let entry = this.runtimeCache.get(key);
    if (!entry || entry.expiresAt < now) {
      entry = { expiresAt: now + RUNTIME_CACHE_TTL_MS, byPlanSession: new Map() };
      this.runtimeCache.set(key, entry);
    }
    let cached = entry.byPlanSession.get(planKey);
    if (!cached) {
      cached = await this.runtime.getContext(userId, planSessionId);
      entry.byPlanSession.set(planKey, cached);
    }
    return cached;
  }

  /**
   * Caminho leve da saudação: nenhum LLM, nenhum RAG, nenhum runtime
   * context pesado. Só busca o profile pra pegar o primeiro nome + voz
   * preferida e monta uma frase template baseada no tipo de corrida.
   *
   * Trade-off: perde personalização longa (que pra saudação não importa)
   * em troca de latência baixa (<3s end-to-end) e zero ponto de falha.
   * Para personalização real, eventos posteriores (km_reached/pace_alert)
   * seguem usando o pipeline completo.
   */
  private readonly _userRepoForStart = new FirestoreUserRepository();

  private async _generateLightweightStart(
    ctx: CoachContext,
    userId: string,
  ): Promise<CoachCueResponse> {
    let firstName: string | null = null;
    try {
      // Profile read com timeout 4s — não quero saudação travada por
      // Firestore lento. Se falhar, segue com saudação genérica.
      const profile = await Promise.race([
        this._userRepoForStart.findById(userId),
        new Promise<null>((resolve) => setTimeout(() => resolve(null), 4000)),
      ]);
      const full = profile?.name?.trim();
      if (full) firstName = full.split(/\s+/)[0] ?? null;
    } catch {
      // Profile read falhou → segue com saudação genérica.
    }

    const runTypeNice = (ctx.runType ?? 'corrida')
      .toLowerCase()
      .replace('free run', 'corrida livre');
    const greeting = firstName
      ? `Bora ${firstName}! Começando a ${runTypeNice}. Vou te acompanhar.`
      : `Bora! Começando a ${runTypeNice}. Vou te acompanhar.`;

    // Timeout overall 15s no synthesize: Live 8s + ElevenLabs ~6s + Google
    // ~3s. Se passar disso, retorna sem áudio — UI mostra só texto, request
    // não fica em 504. Web/Chrome esperam SSE em poucos segundos.
    const audio = await Promise.race([
      this._synthesize(greeting),
      new Promise<null>((resolve) => setTimeout(() => {
        logger.warn('coach.start.synthesize_timeout', { userId, textLen: greeting.length });
        resolve(null);
      }, 15000)),
    ]);
    return {
      text: greeting,
      audioBase64: audio?.audioBase64,
      audioMimeType: audio?.mimeType,
    };
  }

  /**
   * Preview de voz no settings page: sample text curto sintetizado com
   * a voiceId escolhida. Sem LLM, sem RAG, sem decision layer. Cliente
   * só precisa do áudio pra deixar o user ouvir antes de salvar.
   */
  private async _generateVoicePreview(ctx: CoachContext): Promise<CoachCueResponse> {
    const sample = 'Eu vou te acompanhar do início ao fim. Vamos correr juntos.';
    const audio = await Promise.race([
      this._synthesize(sample),
      new Promise<null>((resolve) => setTimeout(() => resolve(null), 10000)),
    ]);
    return {
      text: sample,
      audioBase64: audio?.audioBase64,
      audioMimeType: audio?.mimeType,
    };
  }

  /**
   * Voz ÚNICA: só Gemini Live (Charon). Sem fallback ElevenLabs/Google —
   * trocar de engine gerava vozes diferentes. Retorna null se o Live falhar
   * (texto vai sem áudio).
   */
  private async _synthesize(
    text: string,
  ): Promise<{ audioBase64: string; mimeType: string } | null> {
    const config = await this.config.getConfig();
    if (!config.ttsEnabled) return null;
    return this.liveTts.synthesize(text, { voiceId: 'coach-bruno' });
  }
}

// Eventos "narrativos" são apenas conversa do coach (cor, ânimo, transição).
// Não geram risco se ficarem mudos. silent/alerts_only os bloqueiam.
const NARRATIVE_EVENTS = new Set([
  'km_reached',
  'km_split',
  'motivation',
  'segment_start',
  'segment_end',
]);

// Eventos "críticos" sinalizam risco real (pace muito fora, fim de run).
// Sob silent, podem furar a regra se profile.allowCriticalAlertsInSilent
// === true (default true). pace_alert e segment_pace_off entram aqui;
// finish sempre passa.
const CRITICAL_ALERT_EVENTS = new Set(['pace_alert', 'segment_pace_off']);

function applyDecisionLayer(
  ctx: CoachContext,
  profile: {
    coachMessageFrequency?: string;
    dndWindow?: { start: string; end: string };
    allowCriticalAlertsInSilent?: boolean;
  } | null | undefined,
  knobs: { respectMessageFrequency: boolean; respectDndWindow: boolean },
): CoachCueSkipped | null {
  if (knobs.respectMessageFrequency) {
    const freq = profile?.coachMessageFrequency;
    // silent: bloqueia tudo, exceto críticos quando user permitiu (default true)
    // e finish (sempre passa por ser fechamento da run).
    if (freq === 'silent') {
      if (ctx.event === 'finish') return null;
      const allowCritical = profile?.allowCriticalAlertsInSilent ?? true;
      if (allowCritical && CRITICAL_ALERT_EVENTS.has(ctx.event)) return null;
      return { skipped: true, reason: 'silent' };
    }
    if (ctx.event === 'km_reached' || ctx.event === 'km_split') {
      const km = ctx.kmReached ?? 0;
      if (freq === 'alerts_only') return { skipped: true, reason: 'frequency' };
      if (freq === 'per_2km' && km > 0 && km % 2 !== 0) return { skipped: true, reason: 'frequency' };
    }
    if (freq === 'alerts_only' && NARRATIVE_EVENTS.has(ctx.event)) {
      return { skipped: true, reason: 'frequency' };
    }
  }

  if (knobs.respectDndWindow && profile?.dndWindow && isInDndWindow(profile.dndWindow)) {
    // DND deixa passar alertas críticos e fechamento — risco de lesão e
    // confirmação de término da run são prioritários sobre janela DND.
    if (!CRITICAL_ALERT_EVENTS.has(ctx.event) && ctx.event !== 'finish') {
      return { skipped: true, reason: 'dnd' };
    }
  }

  return null;
}

function formatSessionSummary(
  session: import('@modules/plans/domain/plan.entity').PlanSession | null | undefined,
): string | null {
  if (!session) return null;
  const parts = [session.type];
  if (typeof session.distanceKm === 'number') parts.push(`${session.distanceKm}km`);
  if (session.targetPace) parts.push(`@ ${session.targetPace}`);
  if (typeof session.durationMin === 'number') parts.push(`~${session.durationMin}min`);
  return parts.join(' ');
}

function pickSegment(
  session: import('@modules/plans/domain/plan.entity').PlanSession | null | undefined,
  idx: number | undefined,
): import('@modules/plans/domain/plan.entity').PlanSegment | null {
  if (!session?.executionSegments || typeof idx !== 'number') return null;
  return session.executionSegments[idx] ?? null;
}

function cleanCueText(text: string): string {
  return text
    .replace(/```[\s\S]*?```/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}
