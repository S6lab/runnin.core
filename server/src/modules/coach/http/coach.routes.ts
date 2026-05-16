import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { requireFeature } from '@shared/infra/http/middlewares/require-feature.middleware';
import { postCoachMessage, postCoachChat, getCoachReport, postGenerateReport, getCoachMessagesByRun, getPeriodAnalysis } from './coach.controller';

export const coachRouter = Router();

coachRouter.use(authMiddleware);
// Coach durante corrida (voz/cues)
coachRouter.post('/message', requireFeature('coachVoiceDuringRun'), postCoachMessage);
// Chat texto
coachRouter.post('/chat', requireFeature('coachChat'), postCoachChat);
// Reports + análises pós-corrida
coachRouter.get('/report/:runId', requireFeature('weeklyReports'), getCoachReport);
coachRouter.post('/report/:runId/generate', requireFeature('weeklyReports'), postGenerateReport);
coachRouter.get('/messages/:runId', requireFeature('coachVoiceDuringRun'), getCoachMessagesByRun);
coachRouter.get('/period-analysis', requireFeature('weeklyReports'), getPeriodAnalysis);
