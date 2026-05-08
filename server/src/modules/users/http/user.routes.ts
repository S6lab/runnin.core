import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { getMe, patchMe, postOnboarding, postProvision, postActivateTrial } from './user.controller';

export const userRouter = Router();

userRouter.get('/me', authMiddleware, getMe);
userRouter.post('/provision', authMiddleware, postProvision);
userRouter.patch('/me', authMiddleware, patchMe);
userRouter.post('/onboarding', authMiddleware, postOnboarding);
userRouter.post('/me/trial', authMiddleware, postActivateTrial);
