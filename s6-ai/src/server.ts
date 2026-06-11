import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { requestIdMiddleware } from '@shared/infra/http/middlewares/request-id.middleware';
import { errorMiddleware } from '@shared/infra/http/middlewares/error.middleware';
import { planRouter } from '@modules/plan/plan.routes';
import { liveRouter, ttsRouter } from '@modules/live/live.routes';
import { internalRouter } from '@modules/internal/internal.routes';

export function createServer(): express.Application {
  const app = express();

  app.use(helmet());
  app.use(cors());
  app.use(express.json({ limit: '1mb' }));
  app.use(requestIdMiddleware);

  app.get('/healthz', (_req, res) => {
    res.json({ alive: true, service: 's6-ai', timestamp: new Date().toISOString() });
  });

  app.get('/readyz', async (_req, res) => {
    try {
      const { getFirestore } = await import('@shared/infra/firebase/firebase.client');
      const start = Date.now();
      await getFirestore().collection('app_config').doc('prompts').get();
      res.json({
        ready: true,
        deps: { firestore: { ok: true, latencyMs: Date.now() - start } },
        timestamp: new Date().toISOString(),
      });
    } catch (err) {
      res.status(503).json({
        ready: false,
        error: err instanceof Error ? err.message : String(err),
        timestamp: new Date().toISOString(),
      });
    }
  });

  app.use('/v1/plan', planRouter);
  app.use('/v1/live', liveRouter);
  app.use('/v1/tts', ttsRouter);
  app.use('/v1/internal', internalRouter);

  app.use(errorMiddleware);

  return app;
}
