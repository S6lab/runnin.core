import { Request, Response, NextFunction } from 'express';
import { CoachMessageUseCase, CoachContextSchema, isCueSkipped } from '../use-cases/coach-message.use-case';
import { CoachChatSchema, CoachChatUseCase } from '../use-cases/coach-chat.use-case';
import { GetCoachReportUseCase } from '../use-cases/get-coach-report.use-case';
import { GenerateReportUseCase } from '../use-cases/generate-report.use-case';
import { GeneratePeriodAnalysisUseCase } from '../use-cases/generate-period-analysis.use-case';
import { CreateLiveEphemeralTokenUseCase } from '../use-cases/create-live-ephemeral-token.use-case';
import { CoachRuntimeContextService } from '../use-cases/coach-runtime-context.service';
import { buildRunCoachInstruction } from '../use-cases/build-run-coach-instruction';
import { FirestoreCoachReportRepository } from '../infra/firestore-coach-report.repository';
import { FirestoreRunRepository } from '@modules/runs/infra/firestore-run.repository';
import { NotFoundError } from '@shared/errors/app-error';
import { logger } from '@shared/logger/logger';

const reportRepo = new FirestoreCoachReportRepository();
const runRepoForReports = new FirestoreRunRepository();
const coachMessage = new CoachMessageUseCase();
const coachChat = new CoachChatUseCase();
const getReport = new GetCoachReportUseCase(reportRepo);
const generateReport = new GenerateReportUseCase(reportRepo, runRepoForReports);
const generatePeriodAnalysis = new GeneratePeriodAnalysisUseCase(runRepoForReports);
const createLiveToken = new CreateLiveEphemeralTokenUseCase();
const liveRuntimeContext = new CoachRuntimeContextService();

export async function postCoachLiveToken(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    // planSessionId (opcional) resolve a sessão planejada do dia → o coach
    // recebe o roteiro/segments no systemInstruction. Sem ele = corrida livre.
    const planSessionId =
      (req.query['planSessionId'] as string | undefined) ??
      (req.body?.['planSessionId'] as string | undefined);
    const runtime = await liveRuntimeContext.getContext(req.uid, planSessionId);
    const systemInstruction = await buildRunCoachInstruction(
      runtime,
      runtime.profile?.coachPersonality,
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
    phase: b['phase'],            // 'open_ok' | 'open_failed' | 'ws_close' | 'ws_error'
    code,                         // close code (1008 = safety/size excedido)
    is1008: code === 1008,
    reason: b['reason'],
    error: b['error'],
    sysInstrLen: b['sysInstrLen'],
    outputTranscription: b['outputTranscription'],
    model: b['model'],
    runId: b['runId'],
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
