import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import {
  listNotifications,
  dismissNotification,
  clearNotifications,
  markRead,
} from './notification.controller';

export const notificationRouter = Router();

notificationRouter.get('/', authMiddleware, listNotifications);
notificationRouter.post('/clear', authMiddleware, clearNotifications);
notificationRouter.post('/:id/dismiss', authMiddleware, dismissNotification);
notificationRouter.post('/:id/read', authMiddleware, markRead);
