import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { CoachChatSchema, CoachChatUseCase } from '../use-cases/coach-chat.use-case';
import { GetCoachReportUseCase } from '../use-cases/get-coach-report.use-case';
import { GenerateReportUseCase } from '../use-cases/generate-report.use-case';
import { GeneratePeriodAnalysisUseCase } from '../use-cases/generate-period-analysis.use-case';
import { LogLiveTurnUseCase } from '../use-cases/log-live-turn.use-case';
import { ListCoachMessagesUseCase } from '../use-cases/list-coach-messages.use-case';
import { CoachRuntimeContextService } from '../use-cases/coach-runtime-context.service';
import { isInDndWindow } from '@shared/infra/llm/prompts';
import { S6AiClient, S6LiveSessionContext } from '@shared/infra/s6ai/s6ai.client';
import { s6WsProxyEnabled } from '@shared/infra/s6ai/s6-proxy';
import { FirestoreCoachReportRepository } from '../infra/firestore-coach-report.repository';
import { FirestoreCoachMessageLogRepository } from '../infra/firestore-coach-message-log.repository';
import { FirestoreRunRepository } from '@modules/runs/infra/firestore-run.repository';
import { NotFoundError } from '@shared/errors/app-error';
import { logger } from '@shared/logger/logger';

const reportRepo = new FirestoreCoachReportRepository();
const runRepoForReports = new FirestoreRunRepository();
const coachMessageLogRepo = new FirestoreCoachMessageLogRepository();
const coachChat = new CoachChatUseCase();
const getReport = new GetCoachReportUseCase(reportRepo);
const generateReport = new GenerateReportUseCase(reportRepo, runRepoForReports);
const generatePeriodAnalysis = new GeneratePeriodAnalysisUseCase(runRepoForReports, reportRepo);
const logLiveTurn = new LogLiveTurnUseCase(coachMessageLogRepo);
const listCoachMessages = new ListCoachMessagesUseCase(coachMessageLogRepo);
const liveRuntimeContext = new CoachRuntimeContextService();

// REMOVIDO na migração s6-ai: postCoachLiveToken (token efêmero pra conexão
// app→Google direta). O app agora abre sessão via postCoachLiveSession e
// conecta no WS do s6-ai — GEMINI_API_KEY nunca mais encosta no cliente.

const s6ai = new S6AiClient();

/**
 * Cria a sessão Live no s6-ai (que é o dono do socket Gemini). BFF: monta
 * o blob de contexto agnóstico a partir do Firestore (profile, sessão
 * planejada, prefs) + weather do body, e devolve {sessionId, wsUrl} pro
 * app conectar DIRETO no WS do s6-ai. Substitui o token efêmero
 * (postCoachLiveToken) — o app não fala mais com o Google.
 */
export async function postCoachLiveSession(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const body = (req.body ?? {}) as {
      planSessionId?: string;
      /** Corrida de AVALIAÇÃO: alvo em km. Troca o briefing pra persona de
       *  MEDIÇÃO — sem citar plano/meta de treino, que ainda não existem. */
      assessmentTargetKm?: number;
      temperatureC?: number;
      humidityPercent?: number;
      windKmh?: number;
    };
    const runtime = await liveRuntimeContext.getContext(req.uid, body.planSessionId);
    const p = runtime.profile;

    const profileSnippet = p
      ? [
          p.name ? `nome ${p.name}` : null,
          p.level ? `nível ${p.level}` : null,
          p.goal ? `objetivo "${p.goal}"` : null,
          p.frequency ? `${p.frequency}x/semana` : null,
        ].filter(Boolean).join(', ')
      : 'sem perfil completo';

    const session = runtime.currentSession;
    const briefingParts: string[] = [];
    const assessmentKm =
      typeof body.assessmentTargetKm === 'number' && body.assessmentTargetKm > 0
        ? body.assessmentTargetKm
        : null;
    if (assessmentKm != null) {
      // Persona de MEDIÇÃO durante a sessão inteira: o propósito é capturar
      // o ritmo real do atleta pra calibrar o plano que vem DEPOIS. Não
      // existe plano/sessão/meta de treino ainda — não citar.
      briefingParts.push(
        `SESSÃO DE HOJE: CORRIDA DE AVALIAÇÃO · ${assessmentKm}km.`,
        'MODO MEDIÇÃO — regras desta sessão:',
        '- Briefing: explique o propósito ("vou medir seu ritmo real; corre constante e confortável, sem forçar").',
        '- Check-ins por km: fale só do MEDIDO ("ritmo estável em X:XX, segue assim") — NUNCA cite plano, sessão planejada ou meta de treino (não existem ainda).',
        '- goal_reached: anuncie o resultado medido ("avaliação completa: Xkm a Y/km, FC média Z").',
        '- finish: feche conectando o dado ao que vem: esse ritmo vai calibrar o plano personalizado que o atleta vai criar em seguida.',
      );
    } else if (session) {
      const head = [`SESSÃO DE HOJE: ${session.type}`];
      if (typeof session.distanceKm === 'number') head.push(`${session.distanceKm}km`);
      if (session.targetPace) head.push(`pace alvo ${session.targetPace}`);
      if (typeof session.durationMin === 'number') head.push(`~${session.durationMin}min`);
      briefingParts.push(head.join(' · '));
      // Saudação situada no plano: "semana Y de X do plano {objetivo},
      // hoje {dia}". Compacto de propósito — o briefing entra 2x no
      // systemInstruction (cap 1200 tokens, truncamento dropa weather
      // primeiro) e a saudação vira áudio (~+5s por frase).
      const plan = runtime.currentPlan;
      if (plan?.currentWeek) {
        const weekday = new Intl.DateTimeFormat('pt-BR', {
          weekday: 'long',
          timeZone: 'America/Sao_Paulo',
        }).format(new Date());
        briefingParts.push(
          `PLANO: "${plan.goal}" — semana ${plan.currentWeek.weekNumber} de ${plan.weeksCount}. Hoje é ${weekday}.`,
          'Na SAUDAÇÃO inicial, situe o atleta: nome, semana Y de X do plano, dia da semana e a sessão de hoje — depois o briefing. Máximo 3 frases curtas.',
        );
      }
    } else {
      briefingParts.push('SESSÃO DE HOJE: corrida livre (sem roteiro planejado). Comente o esforço real.');
    }

    // Perfil usa 'per_km' como default falante → mapeia pra 'normal' do
    // s6-ai (que já fala a cada km/500m).
    const freqRaw = p?.coachMessageFrequency;
    const freq: NonNullable<S6LiveSessionContext['prefs']>['freq'] =
      freqRaw === 'silent' || freqRaw === 'alerts_only' || freqRaw === 'per_2km'
        ? freqRaw
        : 'normal';

    const weather =
      typeof body.temperatureC === 'number' ||
      typeof body.humidityPercent === 'number' ||
      typeof body.windKmh === 'number'
        ? {
            temperatureC: body.temperatureC ?? null,
            humidityPercent: body.humidityPercent ?? null,
            windKmh: body.windKmh ?? null,
          }
        : null;

    const context: S6LiveSessionContext = {
      userId: req.uid,
      persona: p?.coachPersonality ?? null,
      voice: 'Charon',
      locale: 'pt-BR',
      profileSnippet,
      sessionBriefing: briefingParts.join('\n'),
      sessionNotes: session?.notes ?? null,
      segments: (session?.executionSegments ?? []).map(s => ({
        kmStart: s.kmStart,
        kmEnd: s.kmEnd,
        phase: s.phase,
        targetPace: s.targetPace ?? null,
        instruction: s.instruction ?? null,
      })),
      weather,
      prefs: {
        freq,
        dnd: !!(p?.dndWindow && isInDndWindow(p.dndWindow)),
        allowCriticalAlertsInSilent: p?.allowCriticalAlertsInSilent ?? true,
      },
      athleteName: p?.name?.split(/\s+/)[0] ?? null,
    };

    const result = await s6ai.createLiveSession(context);
    // STAGING: s6-ai roda sem allUsers (IAM travado) — o app conecta no
    // túnel /v1/live DESTE host, que encaminha autenticado pro s6-ai
    // (vide s6-proxy.ts). S6_WS_PROXY=false volta ao s6-ai direto quando
    // o owner aplicar o binding.
    if (s6WsProxyEnabled()) {
      const host = req.get('host') ?? '';
      const proto = (req.get('x-forwarded-proto') ?? req.protocol) === 'http' ? 'ws' : 'wss';
      result.wsUrl = `${proto}://${host}/v1/live`;
    }
    logger.info('coach.live_session.created', {
      uid: req.uid,
      sessionId: result.sessionId,
      hasPlanSession: !!session,
      wsUrl: result.wsUrl,
    });
    res.json(result);
  } catch (err) {
    next(err);
  }
}

const LiveTurnSchema = z.object({
  runId: z.string().min(1),
  author: z.enum(['coach', 'user']),
  text: z.string().min(1),
  // Os 8 eventos canônicos (migração s6-ai, 16→8). question/push_to_talk
  // morreram junto com o push-to-talk do app.
  event: z
    .enum([
      'start',
      'half_km',
      'km_reached',
      'bpm_alert',
      'pace_alert',
      'goal_reached',
      'finish',
      'no_movement',
    ])
    .optional(),
  kmAtTime: z.number().optional(),
  paceAtTime: z.string().optional(),
  bpmAtTime: z.number().optional(),
  sessionGeneration: z.number().int().nonnegative().optional(),
});

/**
 * Persiste um turno da sessão Gemini Live nativa (cliente conecta direto no
 * Google via token efêmero, então o conteúdo do turno só chega aqui via
 * beacon). Fire-and-forget client-side: 4xx/5xx aqui não afeta UX.
 */
export async function postCoachLiveTurn(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = LiveTurnSchema.parse(req.body);
    await logLiveTurn.execute({ ...input, userId: req.uid });
    res.json({ ok: true });
  } catch (err) {
    logger.warn('coach.live_turn.failed', { uid: req.uid, err: String(err) });
    next(err);
  }
}

/**
 * Beacon de diagnóstico da sessão Gemini Live da run (que conecta direto no
 * Google via token efêmero — o close 1008 não passa pelo nosso server). O
 * cliente reporta open/close/error aqui pra cair no log do Cloud Run, onde
 * dá pra inspecionar `coach.live.client_diag code=1008` em staging.
 */
export function postCoachLiveDiag(req: Request, res: Response): void {
  const b = (req.body ?? {}) as Record<string, unknown>;
  const code = typeof b['code'] === 'number' ? (b['code'] as number) : undefined;
  logger.warn('coach.live.client_diag', {
    uid: req.uid,
    // phase: 'open_ok' | 'open_failed' | 'ws_close' | 'ws_error'
    //      | 'rotate_ok' | 'rotate_failed'
    //      | 'reconnect_attempt' | 'reconnect_ok' | 'reconnect_failed'
    //      | 'token_refresh_required' | 'talk_no_permission' | 'talk_error'
    phase: b['phase'],
    code,                         // close code (1008 = safety/size excedido)
    is1008: code === 1008,
    reason: b['reason'],
    error: b['error'],
    sysInstrLen: b['sysInstrLen'],
    outputTranscription: b['outputTranscription'],
    model: b['model'],
    runId: b['runId'],
    generation: b['generation'],  // sessionGeneration corrente (0 = primeira)
    turns: b['turns'],            // turns acumulados na sessão Live atual
    ageMs: b['ageMs'],            // idade da sessão Live atual em ms
    attempt: b['attempt'],        // nº tentativa de reconexão (1,2,3...)
    // TF 69: diagnose enriquecida do 1008 — última operação na sessão e
    // tempo desde ela. Se close acontece <1s após sendText, era essa
    // operação que API rejeitou.
    lastSendKind: b['lastSendKind'],
    msSinceLastSend: b['msSinceLastSend'],
    // TF 73: preambleLen no open_ok confirma que o contexto foi reinjetado
    // após rotação/reconnect — falas "fora de contexto" pós-TTL costumam
    // ter preambleLen=0 (preamble caiu ou ctxMgr resetou).
    preambleLen: b['preambleLen'],
  });
  res.json({ ok: true });
}

export async function postGenerateReport(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const runId = req.params['runId'] as string;
    const run = await runRepoForReports.findById(runId, req.uid);
    if (!run) throw new NotFoundError('Run');

    const reportId = await generateReport.execute(run, req.uid);
    res.status(202).json({ status: 'ready', reportId });
  } catch (err) {
    next(err);
  }
}

export function triggerReportGeneration(runId: string, userId: string): void {
  runRepoForReports.findById(runId, userId).then(run => {
    if (!run) return;
    generateReport.execute(run, userId).catch(err => {
      logger.warn('coach.report.background_failed', { runId, err: String(err) });
    });
  }).catch(err => {
    logger.warn('coach.report.lookup_failed', { runId, err: String(err) });
  });
}

// REMOVIDO na migração s6-ai: postCoachMessage (/coach/message). Cues de
// corrida agora viajam como frames de evento no WS do s6-ai, com fallback
// HTTP direto no s6-ai (POST /v1/live/sessions/:id/events).

export async function postCoachChat(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = CoachChatSchema.parse(req.body);
    const reply = await coachChat.execute(input, req.uid);
    res.json({ reply });
  } catch (err) {
    next(err);
  }
}

export async function getCoachMessagesByRun(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const runId = req.params['runId'] as string;
    const items = await listCoachMessages.execute(req.uid, runId);
    res.json({ items });
  } catch (err) {
    next(err);
  }
}

export async function getCoachReport(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const runId = req.params['runId'] as string;
    const result = await getReport.execute(req.uid, runId);
    if (result.status === 'pending') {
      res.json({ status: 'pending' });
      return;
    }
    const { report } = result;
    res.json({
      status: 'ready',
      summary: report.summary,
      generatedAt: report.generatedAt,
    });
  } catch (err) {
    next(err);
  }
}

export async function getPeriodAnalysis(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const limit = parseInt(req.query['limit'] as string) || 10;
    const cursor = req.query['cursor'] as string | undefined;
    const result = await generatePeriodAnalysis.execute(req.uid, limit, cursor);
    res.json(result);
  } catch (err) {
    next(err);
  }
}

// === Runtime config (config dinâmica do Coach Live) ===
import { getCoachRuntimeConfig } from '../use-cases/coach-runtime-config.service';

export async function getCoachRuntimeConfigHandler(
  _req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const config = await getCoachRuntimeConfig();
    res.json(config);
  } catch (err) {
    next(err);
  }
}
