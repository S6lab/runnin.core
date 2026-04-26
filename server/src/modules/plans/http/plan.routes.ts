import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { getCurrentPlan, postGeneratePlan, getPlanById, getPlanKnowledge } from './plan.controller';

export const planRouter = Router();

planRouter.use(authMiddleware);
planRouter.get('/knowledge/corpus', getPlanKnowledge);
planRouter.get('/current', getCurrentPlan);
planRouter.post('/generate', postGeneratePlan);
planRouter.get('/:id', getPlanById);
