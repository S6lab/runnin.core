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
import { notificationRouter } from '@modules/notifications/http/notification.routes';
import { wearableRouter } from '@modules/wearable/http/wearable.routes';

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

  // Routes
  app.use('/v1/users', userRouter);
  app.use('/v1/runs', runRouter);
  app.use('/v1/coach', coachRouter);
  app.use('/v1/plans', planRouter);
  app.use('/v1/notifications', notificationRouter);
  app.use('/v1/wearable', wearableRouter);

  app.use(errorMiddleware);

  return app;
}
