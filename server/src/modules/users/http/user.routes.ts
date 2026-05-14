import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { getMe, patchMe, postOnboarding, postProvision, postActivateTrial, getRunPreferencesEndpoint, patchRunPreferences, getMusicPreferencesEndpoint, patchMusicPreferences, postCompleteFirstRun } from './user.controller';

export const userRouter = Router();

userRouter.get('/me', authMiddleware, getMe);
userRouter.post('/provision', authMiddleware, postProvision);
userRouter.patch('/me', authMiddleware, patchMe);
userRouter.post('/onboarding', authMiddleware, postOnboarding);
userRouter.post('/me/trial', authMiddleware, postActivateTrial);

userRouter.get('/run-preferences', authMiddleware, getRunPreferencesEndpoint);
userRouter.patch('/run-preferences', authMiddleware, patchRunPreferences);
userRouter.get('/music-preferences', authMiddleware, getMusicPreferencesEndpoint);
userRouter.patch('/music-preferences', authMiddleware, patchMusicPreferences);

userRouter.post('/complete-first-run', authMiddleware, postCompleteFirstRun);
