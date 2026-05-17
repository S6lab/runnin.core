import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import { requestIdMiddleware } from '@shared/infra/http/middlewares/request-id.middleware';
import { errorMiddleware } from '@shared/infra/http/middlewares/error.middleware';
import { userRouter } from '@modules/users/http/user.routes';
import { runRouter } from '@modules/runs/http/run.routes';
import { coachRouter } from '@modules/coach/http/coach.routes';
import { planRouter } from '@modules/plans/http/plan.routes';
import { weeklyReportRouter } from '@modules/plans/http/weekly-report.routes';
import { notificationRouter } from '@modules/notifications/http/notification.routes';
import { zoneRouter } from '@modules/health/http/zone.routes';
import { examRouter } from '@modules/exams/http/exam.routes';
import { adminRouter } from '@modules/admin/http/admin.routes';
import { benchmarkRoutes } from '@modules/benchmark/http/benchmark.routes';
import { subscriptionRouter } from '@modules/subscriptions/http/subscription.routes';
import { biometricRouter } from '@modules/biometrics/http/biometric.routes';

export function createServer(): express.Application {
  const app = express();

  app.use(helmet());
  app.use(cors());
  app.use(compression());
  app.use(express.json({ limit: '1mb' }));
  app.use(requestIdMiddleware);

  // Health check (sem auth)
  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', version: '1.0.0', timestamp: new Date().toISOString() });
  });

  // Liveness: processo está vivo (não checa nada externo). Cloud Run usa pra
  // detectar deadlock ou processo travado.
  app.get('/healthz', (_req, res) => {
    res.json({ alive: true, timestamp: new Date().toISOString() });
  });

  // Readiness: app está pronto pra servir requests (Firestore alcançável).
  // Cloud Run usa pra deixar de enviar tráfego durante restart/cold start.
  app.get('/readyz', async (_req, res) => {
    try {
      const { getFirestore } = await import('@shared/infra/firebase/firebase.client');
      const start = Date.now();
      await getFirestore().collection('app_config').doc('feature_flags').get();
      const firestoreLatencyMs = Date.now() - start;
      res.json({
        ready: true,
        deps: { firestore: { ok: true, latencyMs: firestoreLatencyMs } },
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

  // Routes
  app.use('/v1/users', userRouter);
  app.use('/v1/runs', runRouter);
  app.use('/v1/coach', coachRouter);
  app.use('/v1/plans', planRouter);
  app.use('/v1/weekly-reports', weeklyReportRouter);
  app.use('/v1/notifications', notificationRouter);
  app.use('/v1/health', zoneRouter);
  app.use('/v1/exams', examRouter);
  app.use('/v1/admin', adminRouter);
  app.use('/v1/benchmark', benchmarkRoutes);
  app.use('/v1/subscriptions', subscriptionRouter);
  app.use('/v1/biometrics', biometricRouter);

  app.use(errorMiddleware);

  return app;
}
