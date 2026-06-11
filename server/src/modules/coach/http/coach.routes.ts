import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { requireFeature } from '@shared/infra/http/middlewares/require-feature.middleware';
import { postCoachChat, getCoachReport, postGenerateReport, getCoachMessagesByRun, getPeriodAnalysis, postCoachLiveDiag, postCoachLiveTurn, postCoachLiveSession, getCoachRuntimeConfigHandler } from './coach.controller';

export const coachRouter = Router();

coachRouter.use(authMiddleware);
// Sessão Live no s6-ai (microsserviço dono do socket Gemini). App recebe
// {sessionId, wsUrl} e conecta no WS do s6-ai. Substituiu o /live-token
// (token efêmero app→Google direto, removido na migração s6-ai).
coachRouter.post('/live-session', requireFeature('coachVoiceDuringRun'), postCoachLiveSession);
// Beacon de diagnóstico da sessão Live (open/close/error) — pra rastrear 1008.
coachRouter.post('/live-diag', postCoachLiveDiag);
// Persistência de cada turno da sessão Live (coach) pra replay e auditoria
// — o app beacona o cue_text recebido do WS do s6-ai (o histórico vive no
// schema do app, então fica aqui, não no s6-ai).
coachRouter.post('/live-turn', requireFeature('coachVoiceDuringRun'), postCoachLiveTurn);
// /coach/message REMOVIDO (migração s6-ai): cues vão pelo WS do s6-ai
// com fallback HTTP direto lá (POST /v1/live/sessions/:id/events).
// Chat texto
coachRouter.post('/chat', requireFeature('coachChat'), postCoachChat);
// Reports + análises pós-corrida
coachRouter.get('/report/:runId', requireFeature('weeklyReports'), getCoachReport);
coachRouter.post('/report/:runId/generate', requireFeature('weeklyReports'), postGenerateReport);
coachRouter.get('/messages/:runId', requireFeature('coachVoiceDuringRun'), getCoachMessagesByRun);
coachRouter.get('/period-analysis', requireFeature('weeklyReports'), getPeriodAnalysis);

// Runtime config (intervalo cue, cooldowns, rotação Live). App fetcha no boot,
// cacheia 1h em Hive. Admin pode editar `app_config/coach_runtime` sem deploy.
coachRouter.get('/runtime-config', getCoachRuntimeConfigHandler);
