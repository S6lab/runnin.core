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
  getRagStatus,
} from './admin.controller';

export const adminRouter = Router();

// Bootstrap: aceita X-Cron-Token (mesmo do Cloud Scheduler) pra promover
// testers sem precisar de ID token de admin pré-existente. Útil em setup
// inicial de testers; idempotente.
adminRouter.post('/tester/seed', cronTokenMiddleware, postSeedTester);

adminRouter.use(authMiddleware);
adminRouter.use(requireAdmin);
adminRouter.post('/prompts/preview', postPromptPreview);
adminRouter.get('/prompts/defaults', getPromptDefaults);
adminRouter.post('/prompts/invalidate-cache', postInvalidateCache);
adminRouter.get('/users', getUsersList);
adminRouter.patch('/users/:userId/plan', patchUserPlan);
adminRouter.get('/rag/status', getRagStatus);
adminRouter.post('/rag/reindex', postRagReindex);
