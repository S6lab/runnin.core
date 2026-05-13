import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import {
  postSync,
  getConnection,
  getHeartRate,
  getZones,
  getRecovery,
  getSleep,
  getActivity,
} from './wearable.controller';

export const wearableRouter = Router();

wearableRouter.use(authMiddleware);

// Sync data from client
wearableRouter.post('/sync', postSync);

// Get connection status
wearableRouter.get('/connection', getConnection);

// Get specific data types
wearableRouter.get('/heart-rate', getHeartRate);
wearableRouter.get('/zones', getZones);
wearableRouter.get('/recovery', getRecovery);
wearableRouter.get('/sleep', getSleep);
wearableRouter.get('/activity', getActivity);
