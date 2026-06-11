import { Router, Request, Response, NextFunction } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { internalTokenMiddleware } from '@shared/infra/http/middlewares/internal-token.middleware';
import { getRealtimeLLM } from '@shared/infra/llm/llm.factory';
import { GeminiLiveTtsService } from '@shared/infra/llm/gemini-live-tts.service';
import { resolvePersonaTone } from '@shared/infra/llm/prompts/persona/resolver';
import { logger } from '@shared/logger/logger';
import { z } from 'zod';
import { cueSessionStore } from './cue-session.store';
import { LiveSessionContextSchema } from './live-session.types';
import { CUE_EVENTS, TEMPLATE_EVENTS, TelemetrySnapshotSchema } from './cue-events';
import { applyPrefsGate, formatEventTurn } from './cue-pipeline';
import { tryBuildTemplate } from './template-cues';
import { getActiveBridge } from './live.ws';

const liveTts = new GeminiLiveTtsService();
const realtimeLlm = getRealtimeLLM();

export const liveRouter = Router();

// ── Criação de sessão (s2s: runnin-api monta o blob no run-start) ──
const CreateSessionSchema = z.object({ context: LiveSessionContextSchema });

liveRouter.post(
  '/sessions',
  internalTokenMiddleware,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { context } = CreateSessionSchema.parse(req.body);
      const session = await cueSessionStore.create(context);
      const host = (process.env['S6_PUBLIC_URL'] ?? `https://${req.headers.host}`).replace(/\/$/, '');
      const wsUrl = `${host.replace(/^http/, 'ws')}/v1/live`;
      res.status(201).json({
        sessionId: session.id,
        wsUrl,
        expiresAt: new Date(Date.now() + 8 * 60 * 60 * 1000).toISOString(),
      });
    } catch (err) {
      next(err);
    }
  },
);

// ── Fallback HTTP de eventos (WS caído). Auth do USUÁRIO. ──
const EventBodySchema = z.object({
  event: z.enum(CUE_EVENTS),
  data: TelemetrySnapshotSchema.default({ kmDone: 0, elapsedS: 0 }),
});

liveRouter.post(
  '/sessions/:id/events',
  authMiddleware,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const sessionId = req.params['id'] as string;
      const session = await cueSessionStore.getOrRehydrate(sessionId);
      if (!session || session.context.userId !== req.uid) {
        res.status(404).json({ error: { code: 'SESSION_NOT_FOUND' } });
        return;
      }
      const { event, data } = EventBodySchema.parse(req.body);
      session.touch();

      // WS ativo? O canal certo é o frame de evento — evita fala duplicada
      // (app só deveria cair aqui com WS down; defesa contra corrida).
      if (getActiveBridge(sessionId)) {
        res.status(409).json({ error: { code: 'WS_ACTIVE', message: 'Envie o evento pelo WebSocket.' } });
        return;
      }

      const skip = applyPrefsGate(session, event);
      if (skip || (session.context.prefs.freq === 'per_2km' && event === 'km_reached' && Math.floor(data.kmDone) % 2 !== 0)) {
        res.status(204).setHeader('X-Cue-Skip-Reason', skip ?? 'frequency').end();
        return;
      }
      const enq = session.queue.tryEnqueue(event, data);
      if (!enq.accepted) {
        res.status(204).setHeader('X-Cue-Skip-Reason', enq.reason).end();
        return;
      }
      // Sem Live: entrega é resposta HTTP (texto + áudio TTS). A fila só
      // serviu de dedup — completa imediatamente.
      session.queue.next();
      session.queue.complete();

      let text: string;
      const template = TEMPLATE_EVENTS.has(event)
        ? tryBuildTemplate(event, data, session.context)
        : null;
      if (template) {
        text = template.text;
      } else {
        const tone = await resolvePersonaTone(session.context.persona ?? undefined);
        const raw = await realtimeLlm.generate(
          `${formatEventTurn(event, data, session)}\n\nFale com o atleta sobre esse momento da corrida.`,
          {
            systemPrompt: [
              `Você é um coach de corrida AO VIVO. Tom: ${tone}.`,
              `Atleta: ${session.context.profileSnippet}.`,
              session.context.sessionBriefing,
              'Responda em PT-BR, 1-2 frases curtas, faladas, sem markdown, sem emojis. Pace sempre no formato "5min30".',
            ].filter(Boolean).join('\n'),
            maxTokens: 120,
            temperature: 0.7,
            userId: session.context.userId,
            useCase: 'coach-message',
          },
        );
        text = raw.replace(/\s+/g, ' ').trim();
      }
      session.appendCue(text);
      if (event === 'goal_reached') session.switchToFreeMode();

      const audio = await liveTts
        .synthesize(text, { voiceId: 'coach-bruno' })
        .catch((err) => {
          logger.warn('live.fallback.tts_failed', { sessionId, err: String(err) });
          return null;
        });

      logger.info('live.fallback.delivered', { sessionId, event, hasAudio: !!audio });
      res.json({
        text,
        audioB64: audio?.audioBase64,
        audioMimeType: audio?.mimeType,
      });
    } catch (err) {
      next(err);
    }
  },
);

// ── Encerramento explícito (run finalizada) ──
liveRouter.delete(
  '/sessions/:id',
  authMiddleware,
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const sessionId = req.params['id'] as string;
      const session = await cueSessionStore.getOrRehydrate(sessionId);
      if (session && session.context.userId !== req.uid) {
        res.status(403).json({ error: { code: 'FORBIDDEN' } });
        return;
      }
      getActiveBridge(sessionId)?.dispose();
      await cueSessionStore.destroy(sessionId);
      res.json({ ok: true });
    } catch (err) {
      next(err);
    }
  },
);

// ── Preview de voz (Settings) — substitui o event=preview legado ──
const TtsPreviewSchema = z.object({
  voiceId: z.string().default('coach-bruno'),
  sampleText: z.string().max(200).default('Eu vou te acompanhar do início ao fim. Vamos correr juntos.'),
});

export const ttsRouter = Router();

ttsRouter.post('/preview', authMiddleware, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { voiceId, sampleText } = TtsPreviewSchema.parse(req.body ?? {});
    const audio = await Promise.race([
      liveTts.synthesize(sampleText, { voiceId }),
      new Promise<null>((resolve) => setTimeout(() => resolve(null), 10_000)),
    ]);
    res.json({
      text: sampleText,
      audioB64: audio?.audioBase64,
      audioMimeType: audio?.mimeType,
    });
  } catch (err) {
    next(err);
  }
});
