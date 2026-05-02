import { Request, Response, NextFunction } from 'express';
import { CoachMessageUseCase, CoachContextSchema } from '../use-cases/coach-message.use-case';
import { CoachChatSchema, CoachChatUseCase } from '../use-cases/coach-chat.use-case';
import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { logger } from '@shared/logger/logger';

const coachMessage = new CoachMessageUseCase();
const coachChat = new CoachChatUseCase();

export async function postCoachMessage(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const ctx = CoachContextSchema.parse(req.body);
    const cue = await coachMessage.generate(ctx, req.uid);

    // SSE headers
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
    const doc = await getFirestore()
      .collection(`users/${req.uid}/runs/${runId}/reports`)
      .doc(runId)
      .get();

    if (!doc.exists) {
      res.json({ status: 'pending' });
      return;
    }

    res.json({ status: 'ready', ...doc.data() });
  } catch (err) {
    next(err);
  }
}
