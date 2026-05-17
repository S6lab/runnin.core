import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { requireFeature } from '@shared/infra/http/middlewares/require-feature.middleware';
import { postCoachMessage, postCoachChat, getCoachReport, postGenerateReport, getCoachMessagesByRun, getPeriodAnalysis, postCoachLiveToken } from './coach.controller';

export const coachRouter = Router();

coachRouter.use(authMiddleware);
// Token efêmero pra app conectar direto no Gemini Live (sem expor a
// API key real). Token tem 30min de validade, 1 uso. Premium-gated
// pelo mesmo feature flag dos cues durante a corrida.
coachRouter.post('/live-token', requireFeature('coachVoiceDuringRun'), postCoachLiveToken);
// Coach durante corrida (voz/cues)
coachRouter.post('/message', requireFeature('coachVoiceDuringRun'), postCoachMessage);
// Chat texto
coachRouter.post('/chat', requireFeature('coachChat'), postCoachChat);
// Reports + análises pós-corrida
coachRouter.get('/report/:runId', requireFeature('weeklyReports'), getCoachReport);
coachRouter.post('/report/:runId/generate', requireFeature('weeklyReports'), postGenerateReport);
coachRouter.get('/messages/:runId', requireFeature('coachVoiceDuringRun'), getCoachMessagesByRun);
coachRouter.get('/period-analysis', requireFeature('weeklyReports'), getPeriodAnalysis);
