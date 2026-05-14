import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { getGamification, postXp, getBadges } from './gamification.controller';

export const gamificationRouter = Router();

gamificationRouter.use(authMiddleware);
gamificationRouter.get('/profile', getGamification);
gamificationRouter.post('/xp', postXp);
gamificationRouter.get('/badges', getBadges);
