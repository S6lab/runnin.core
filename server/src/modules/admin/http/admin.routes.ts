import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { requireAdmin } from '@shared/infra/http/middlewares/require-admin.middleware';
import { cronTokenMiddleware } from '@shared/infra/http/middlewares/cron-token.middleware';
import {
  postPromptPreview,
  getPromptDefaults,
  postInvalidateCache,
  getUsersList,
  patchUserPlan,
  postSeedTester,
  postRagReindex,
  postRagPurge,
  getRagStatus,
  getRoteiroTemplatesDefaults,
  postInvalidateRoteiroCache,
  getDiagnoseUser,
  postDiagnoseRegeneratePlan,
  postDiagnoseResetJourney,
  postDiagnoseWeeklyRevise,
  postCronWeeklyProposals,
  postCronWeeklyProposalUser,
  postAdminWeeklyProposalsTrigger,
  postUserReset,
  getPromptsRegistry,
  getCoachAiMoments,
  getCronsList,
  getPlansCatalog,
  getPlanRules,
  getAdminWiringStatus,
  postSetAdminClaim,
  postDevLogin,
} from './admin.controller';

export const adminRouter = Router();

// Bootstrap: aceita X-Cron-Token (mesmo do Cloud Scheduler) pra promover
// testers sem precisar de ID token de admin pré-existente. Útil em setup
// inicial de testers; idempotente.
adminRouter.post('/tester/seed', cronTokenMiddleware, postSeedTester);
adminRouter.get('/diagnose/user', cronTokenMiddleware, getDiagnoseUser);
adminRouter.post('/diagnose/regenerate-plan', cronTokenMiddleware, postDiagnoseRegeneratePlan);
adminRouter.post('/diagnose/reset-journey', cronTokenMiddleware, postDiagnoseResetJourney);
adminRouter.post('/diagnose/weekly-revise', cronTokenMiddleware, postDiagnoseWeeklyRevise);
adminRouter.post('/cron/weekly-proposals', cronTokenMiddleware, postCronWeeklyProposals);
adminRouter.post('/cron/weekly-proposals/user', cronTokenMiddleware, postCronWeeklyProposalUser);

// Bootstrap admin claim. X-Cron-Token (não admin auth) porque é a rota
// usada pra promover o PRIMEIRO admin — chicken-and-egg se exigíssemos
// claim admin pra setar claim admin. Aceita email ou phone (E.164).
adminRouter.post('/users/admin-claim', cronTokenMiddleware, postSetAdminClaim);

// Dev/Postman login: proxy pra Identity Toolkit signInWithPassword. Devolve
// idToken+refreshToken prontos pra usar nas rotas autenticadas. Protegido
// por X-Cron-Token pra não virar proxy de brute-force. Exige
// FIREBASE_WEB_API_KEY no env do server.
adminRouter.post('/dev/login', cronTokenMiddleware, postDevLogin);

adminRouter.use(authMiddleware);
adminRouter.use(requireAdmin);
adminRouter.post('/prompts/preview', postPromptPreview);
adminRouter.get('/prompts/defaults', getPromptDefaults);
adminRouter.post('/prompts/invalidate-cache', postInvalidateCache);
adminRouter.get('/users', getUsersList);
adminRouter.patch('/users/:userId/plan', patchUserPlan);
adminRouter.post('/users/:userId/reset', postUserReset);
adminRouter.get('/rag/status', getRagStatus);
adminRouter.post('/rag/reindex', postRagReindex);
adminRouter.post('/rag/purge', postRagPurge);
adminRouter.get('/roteiro-templates/defaults', getRoteiroTemplatesDefaults);
adminRouter.post('/roteiro-templates/invalidate-cache', postInvalidateRoteiroCache);
// Disparo manual da revisão semanal — simula o cron de domingo sem ter que
// esperar o scheduler. Usa auth admin (não X-Cron-Token) pra ser tocável
// do admin panel da app.
adminRouter.post('/cron/weekly-proposals/trigger', postAdminWeeklyProposalsTrigger);

// ─── Registry endpoints (dynamic discovery) ──────────────────────────────
// Source-of-truth pra listas que antes ficavam hardcoded no app admin.
// Mexer aqui = mexer no admin sem deploy do Flutter. Read-only.
adminRouter.get('/prompts/registry', getPromptsRegistry);
adminRouter.get('/coach-ai/moments', getCoachAiMoments);
adminRouter.get('/crons', getCronsList);
adminRouter.get('/users/plans-catalog', getPlansCatalog);
adminRouter.get('/constants/plan-rules', getPlanRules);
adminRouter.get('/wiring-status', getAdminWiringStatus);
