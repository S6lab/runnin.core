import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { cronTokenMiddleware } from '@shared/infra/http/middlewares/cron-token.middleware';
import { getMe, patchMe, postOnboarding, postProvision, postActivateTrial, postResetPlanRevisionsQuota, deleteMe } from './user.controller';

export const userRouter = Router();

userRouter.get('/me', authMiddleware, getMe);
userRouter.post('/provision', authMiddleware, postProvision);
userRouter.patch('/me', authMiddleware, patchMe);
userRouter.delete('/me', authMiddleware, deleteMe);
userRouter.post('/onboarding', authMiddleware, postOnboarding);
userRouter.post('/me/trial', authMiddleware, postActivateTrial);
userRouter.post('/internal/reset-plan-revision-quota', cronTokenMiddleware, postResetPlanRevisionsQuota);
