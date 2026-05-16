import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { requirePremium } from '@shared/infra/http/middlewares/require-premium.middleware';
import { postCoachMessage, postCoachChat, getCoachReport, postGenerateReport, getCoachMessagesByRun, getPeriodAnalysis } from './coach.controller';

export const coachRouter = Router();

coachRouter.use(authMiddleware);
coachRouter.use(requirePremium);
coachRouter.post('/message', postCoachMessage);
coachRouter.post('/chat', postCoachChat);
coachRouter.get('/report/:runId', getCoachReport);
coachRouter.post('/report/:runId/generate', postGenerateReport);
coachRouter.get('/messages/:runId', getCoachMessagesByRun);
 coachRouter.get('/period-analysis', getPeriodAnalysis);
