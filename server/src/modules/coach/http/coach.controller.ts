import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { CoachMessageUseCase, CoachContextSchema, isCueSkipped } from '../use-cases/coach-message.use-case';
import { CoachChatSchema, CoachChatUseCase } from '../use-cases/coach-chat.use-case';
import { GetCoachReportUseCase } from '../use-cases/get-coach-report.use-case';
import { GenerateReportUseCase } from '../use-cases/generate-report.use-case';
import { GeneratePeriodAnalysisUseCase } from '../use-cases/generate-period-analysis.use-case';
import { CreateLiveEphemeralTokenUseCase } from '../use-cases/create-live-ephemeral-token.use-case';
import { LogLiveTurnUseCase } from '../use-cases/log-live-turn.use-case';
import { CoachRuntimeContextService } from '../use-cases/coach-runtime-context.service';
import { buildRunCoachInstruction } from '../use-cases/build-run-coach-instruction';
import { FirestoreCoachReportRepository } from '../infra/firestore-coach-report.repository';
import { FirestoreCoachMessageLogRepository } from '../infra/firestore-coach-message-log.repository';
import { FirestoreRunRepository } from '@modules/runs/infra/firestore-run.repository';
import { NotFoundError } from '@shared/errors/app-error';
import { logger } from '@shared/logger/logger';

const reportRepo = new FirestoreCoachReportRepository();
const runRepoForReports = new FirestoreRunRepository();
const coachMessageLogRepo = new FirestoreCoachMessageLogRepository();
const coachMessage = new CoachMessageUseCase();
const coachChat = new CoachChatUseCase();
const getReport = new GetCoachReportUseCase(reportRepo);
const generateReport = new GenerateReportUseCase(reportRepo, runRepoForReports);
const generatePeriodAnalysis = new GeneratePeriodAnalysisUseCase(runRepoForReports, reportRepo);
const createLiveToken = new CreateLiveEphemeralTokenUseCase();
const logLiveTurn = new LogLiveTurnUseCase(coachMessageLogRepo);
const liveRuntimeContext = new CoachRuntimeContextService();

export async function postCoachLiveToken(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    // planSessionId (opcional) resolve a sessão planejada do dia → o coach
    // recebe o roteiro/segments no systemInstruction. Sem ele = corrida livre.
    const planSessionId =
      (req.query['planSessionId'] as string | undefined) ??
      (req.body?.['planSessionId'] as string | undefined);
    const runtime = await liveRuntimeContext.getContext(req.uid, planSessionId);
    // Weather opcional — app passa snapshot capturado no início da corrida.
    const body = (req.body ?? {}) as {
      temperatureC?: number;
      humidityPercent?: number;
      windKmh?: number;
    };
    const weather =
      typeof body.temperatureC === 'number' ||
      typeof body.humidityPercent === 'number' ||
      typeof body.windKmh === 'number'
        ? {
            temperatureC: body.temperatureC,
            humidityPercent: body.humidityPercent,
            windKmh: body.windKmh,
          }
        : undefined;
    const systemInstruction = await buildRunCoachInstruction(
      runtime,
      runtime.profile?.coachPersonality,
      weather,
    );
    const result = await createLiveToken.execute({
      systemInstruction,
      outputTranscription: true,
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
  event: z
    .enum([
      'pre_run',
      'start',
      'km_reached',
      'km_split',
      'pace_alert',
      'high_bpm',
      'motivation',
      'finish',
      'question',
      'preview',
      'segment_start',
      'segment_pace_off',
      'segment_end',
      'push_to_talk',
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

export async function postCoachMessage(req: Request, res: Response, next: NextFunction): Promise<void> {
  // Logamos o event ANTES do parse pra capturar até payloads que falham
  // validação (sem isso, eventos novos rejeitados ficavam invisíveis nos logs
  // — usuário via "coach não fala" mas nada aparecia aqui).
  const rawEvent = (req.body as { event?: unknown })?.event;
  const rawKm = (req.body as { kmReached?: unknown })?.kmReached;
  const rawRunId = (req.body as { runId?: unknown })?.runId;
  logger.info('coach.message.received', { event: rawEvent, kmReached: rawKm, runId: rawRunId, uid: req.uid });

  try {
    const ctx = CoachContextSchema.parse(req.body);
    const result = await coachMessage.generate(ctx, req.uid);

    if (isCueSkipped(result)) {
      logger.info('coach.message.skipped', { event: ctx.event, reason: result.reason, uid: req.uid });
      res.status(204).setHeader('X-Coach-Skip-Reason', result.reason).end();
      return;
    }

    logger.info('coach.message.completed', {
      event: ctx.event,
      textLen: result.text.length,
      hasAudio: !!result.audioBase64,
      uid: req.uid,
    });

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.flushHeaders();

    res.write(`data: ${JSON.stringify(result)}\n\n`);
    res.write('data: [DONE]\n\n');
    res.end();
  } catch (err) {
    // Inclui body inteira (sanitizada) pra ver QUAL valor foi rejeitado
    // pelo schema — Zod mostrava só os valid values, sem o input que falhou.
    const safeBody: Record<string, unknown> = {};
    if (req.body && typeof req.body === 'object') {
      for (const [k, v] of Object.entries(req.body as Record<string, unknown>)) {
        safeBody[k] = typeof v === 'string' && v.length > 80 ? `${v.slice(0, 80)}…` : v;
      }
    }
    logger.warn('coach.message.failed', {
      event: rawEvent,
      body: safeBody,
      err: String(err),
      uid: req.uid,
    });
    next(err);
  }
}

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
    const items = await coachMessage.listForRun(req.uid, runId);
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
