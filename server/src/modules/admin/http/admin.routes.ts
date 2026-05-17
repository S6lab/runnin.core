import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { requireAdmin } from '@shared/infra/http/middlewares/require-admin.middleware';
import {
  postPromptPreview,
  getPromptDefaults,
  postInvalidateCache,
  getUsersList,
  patchUserPlan,
} from './admin.controller';

export const adminRouter = Router();

adminRouter.use(authMiddleware);
adminRouter.use(requireAdmin);
adminRouter.post('/prompts/preview', postPromptPreview);
adminRouter.get('/prompts/defaults', getPromptDefaults);
adminRouter.post('/prompts/invalidate-cache', postInvalidateCache);
adminRouter.get('/users', getUsersList);
adminRouter.patch('/users/:userId/plan', patchUserPlan);
