import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { getMe, patchMe, postOnboarding, postProvision, postActivateTrial, getRunPreferencesEndpoint, patchRunPreferences, getMusicPreferencesEndpoint, patchMusicPreferences, getHasCompletedFirstRunEndpoint, postCompleteFirstRun } from './user.controller';

/**
 * User routes configuration
 * Authentication: All endpoints require valid Firebase ID token in Authorization header
 *
 * Endpoints:
 *   GET  /me                   - Get user profile (includes hasCompletedFirstRun field)
 *   POST /provision            - Provision new user
 *   PATCH /me                  - Update user profile
 *   POST /onboarding           - Complete onboarding
 *   POST /me/trial             - Activate free trial
 *   GET  /run-preferences      - Get run alert preferences
 *   PATCH /run-preferences     - Update run alert preferences
 *   GET  /music-preferences    - Get music preferences
 *   PATCH /music-preferences   - Update music preferences
 *   GET  /has-completed-first-run - Check if user completed their first run (NEW)
 *   POST /complete-first-run   - Mark user's first run as complete (NEW)
 */
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

userRouter.get('/has-completed-first-run', authMiddleware, getHasCompletedFirstRunEndpoint);
userRouter.post('/complete-first-run', authMiddleware, postCompleteFirstRun);
