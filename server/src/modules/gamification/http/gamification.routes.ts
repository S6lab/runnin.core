import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { getGamification } from './gamification.controller';

export const gamificationRouter = Router();

gamificationRouter.use(authMiddleware);
gamificationRouter.get('/', getGamification);
