import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { requireAdmin } from '@shared/infra/http/middlewares/require-admin.middleware';
import {
  postIngestSamples,
  postSyncTelemetry,
  postSyncPing,
  getLatestByType,
  getSummary,
  postSeedTestUser,
} from './biometric.controller';

export const biometricRouter = Router();

biometricRouter.use(authMiddleware);
biometricRouter.post('/samples', postIngestSamples);
biometricRouter.post('/sync-telemetry', postSyncTelemetry);
biometricRouter.post('/sync-ping', postSyncPing);
biometricRouter.get('/latest/:type', getLatestByType);
biometricRouter.get('/summary', getSummary);

// Admin-only seed (popula 7d de dados realistas pra user de teste)
biometricRouter.post('/seed-test-user', requireAdmin, postSeedTestUser);
