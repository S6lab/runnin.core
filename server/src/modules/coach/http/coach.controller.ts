import { Request, Response, NextFunction } from 'express';
import { CoachMessageUseCase, CoachContextSchema } from '../use-cases/coach-message.use-case';
import { CoachChatSchema, CoachChatUseCase } from '../use-cases/coach-chat.use-case';
import { GetCoachReportUseCase } from '../use-cases/get-coach-report.use-case';
import { FirestoreCoachReportRepository } from '../infra/firestore-coach-report.repository';

const reportRepo = new FirestoreCoachReportRepository();
const coachMessage = new CoachMessageUseCase();
const coachChat = new CoachChatUseCase();
const getReport = new GetCoachReportUseCase(reportRepo);

export async function postCoachMessage(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const ctx = CoachContextSchema.parse(req.body);
    const cue = await coachMessage.generate(ctx, req.uid);

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.flushHeaders();

    res.write(`data: ${JSON.stringify(cue)}\n\n`);
    res.write('data: [DONE]\n\n');
    res.end();
  } catch (err) {
    next(err);
  }
}

export async function postCoachChat(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = CoachChatSchema.parse(req.body);
    const reply = await coachChat.execute(input);
    res.json({ reply });
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
