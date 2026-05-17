import { Request, Response, NextFunction } from 'express';
import { CoachMessageUseCase, CoachContextSchema, isCueSkipped } from '../use-cases/coach-message.use-case';
import { CoachChatSchema, CoachChatUseCase } from '../use-cases/coach-chat.use-case';
import { GetCoachReportUseCase } from '../use-cases/get-coach-report.use-case';
import { GenerateReportUseCase } from '../use-cases/generate-report.use-case';
import { GeneratePeriodAnalysisUseCase } from '../use-cases/generate-period-analysis.use-case';
import { CreateLiveEphemeralTokenUseCase } from '../use-cases/create-live-ephemeral-token.use-case';
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

export async function postCoachLiveToken(_req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const result = await createLiveToken.execute();
    res.json(result);
  } catch (err) {
    next(err);
  }
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
  try {
    const ctx = CoachContextSchema.parse(req.body);
    const result = await coachMessage.generate(ctx, req.uid);

    if (isCueSkipped(result)) {
      // Decision layer pulou esta mensagem (frequency / DND / silent)
      res.status(204).setHeader('X-Coach-Skip-Reason', result.reason).end();
      return;
    }

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.flushHeaders();

    res.write(`data: ${JSON.stringify(result)}\n\n`);
    res.write('data: [DONE]\n\n');
    res.end();
  } catch (err) {
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
