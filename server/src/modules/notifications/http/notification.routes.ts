import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { cronTokenMiddleware } from '@shared/infra/http/middlewares/cron-token.middleware';
import {
  listNotifications,
  dismissNotification,
  clearNotifications,
  markRead,
  ensureDailyNotifications,
  registerDevice,
} from './notification.controller';

export const notificationRouter = Router();

notificationRouter.get('/', authMiddleware, listNotifications);
notificationRouter.post('/clear', authMiddleware, clearNotifications);
notificationRouter.post('/:id/dismiss', authMiddleware, dismissNotification);
notificationRouter.post('/:id/read', authMiddleware, markRead);
notificationRouter.post('/devices', authMiddleware, registerDevice);
notificationRouter.post('/ensure-daily', cronTokenMiddleware, ensureDailyNotifications);
