import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { postCoachMessage, postCoachChat, getCoachReport } from './coach.controller';

export const coachRouter = Router();

coachRouter.use(authMiddleware);
coachRouter.post('/message', postCoachMessage);
coachRouter.post('/chat', postCoachChat);
coachRouter.get('/report/:runId', getCoachReport);
