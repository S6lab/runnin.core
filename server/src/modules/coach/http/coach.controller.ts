import { Request, Response, NextFunction } from 'express';
import { CoachMessageUseCase, CoachContextSchema } from '../use-cases/coach-message.use-case';
import { CoachChatSchema, CoachChatUseCase } from '../use-cases/coach-chat.use-case';
import { GenerateBriefingUseCase } from '../use-cases/generate-briefing.use-case';
import { GenerateVoiceAlertUseCase } from '../use-cases/generate-voice-alert.use-case';
import { VoiceAlertRulesEngine } from '../use-cases/voice-alert-rules.engine';
import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { logger } from '@shared/logger/logger';
import { z } from 'zod';

const coachMessage = new CoachMessageUseCase();
const coachChat = new CoachChatUseCase();
const generateBriefing = new GenerateBriefingUseCase();
const generateVoiceAlert = new GenerateVoiceAlertUseCase();
const voiceAlertRules = new VoiceAlertRulesEngine();

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

const GenerateBriefingSchema = z.object({
  sessionType: z.string().min(1),
  distanceKm: z.number().positive(),
  targetPace: z.string().optional(),
  planSessionId: z.string().optional(),
  sessionNotes: z.string().optional(),
});

export async function postGenerateBriefing(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = GenerateBriefingSchema.parse(req.body);
    const result = await generateBriefing.execute(req.uid, input);
    res.json(result);
  } catch (err) {
    next(err);
  }
}

const GenerateVoiceAlertSchema = z.object({
  alertType: z.enum([
    'pace_too_fast',
    'pace_too_slow',
    'pace_on_target',
    'hr_zone_high',
    'hr_zone_low',
    'hr_zone_optimal',
    'distance_milestone',
    'time_milestone',
    'encouragement',
    'halfway_point',
    'final_push',
  ]),
  context: z.object({
    currentPace: z.string().optional(),
    targetPace: z.string().optional(),
    currentBpm: z.number().optional(),
    targetBpmZone: z.object({ min: z.number(), max: z.number() }).optional(),
    distanceKm: z.number().optional(),
    targetDistanceKm: z.number().optional(),
    elapsedMinutes: z.number().optional(),
    sessionType: z.string().optional(),
  }),
});

export async function postGenerateVoiceAlert(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = GenerateVoiceAlertSchema.parse(req.body);
    const result = await generateVoiceAlert.execute(req.uid, input);
    res.json(result);
  } catch (err) {
    next(err);
  }
}

const EvaluateVoiceAlertSchema = z.object({
  currentPace: z.string().optional(),
  targetPace: z.string().optional(),
  currentBpm: z.number().optional(),
  targetBpmZone: z.object({ min: z.number(), max: z.number() }).optional(),
  distanceKm: z.number(),
  targetDistanceKm: z.number().optional(),
  elapsedSeconds: z.number(),
  sessionType: z.string().optional(),
  lastAlertTimestamp: z.number().optional(),
  lastAlertType: z.string().optional(),
});

export async function postEvaluateVoiceAlert(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const metrics = EvaluateVoiceAlertSchema.parse(req.body);
    const trigger = voiceAlertRules.evaluateAlerts(metrics as any);

    if (!trigger || !trigger.shouldTrigger) {
      res.json({ shouldTrigger: false });
      return;
    }

    // Generate the actual alert
    const result = await generateVoiceAlert.execute(req.uid, {
      alertType: trigger.alertType,
      context: {
        currentPace: metrics.currentPace,
        targetPace: metrics.targetPace,
        currentBpm: metrics.currentBpm,
        targetBpmZone: metrics.targetBpmZone,
        distanceKm: metrics.distanceKm,
        targetDistanceKm: metrics.targetDistanceKm,
        elapsedMinutes: Math.floor(metrics.elapsedSeconds / 60),
        sessionType: metrics.sessionType,
      },
    });

    res.json({
      shouldTrigger: true,
      priority: trigger.priority,
      reason: trigger.reason,
      ...result,
    });
  } catch (err) {
    next(err);
  }
}
