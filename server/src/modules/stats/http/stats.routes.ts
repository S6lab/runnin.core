import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { getStatsAggregate } from './stats.controller';

export const statsRouter = Router();

statsRouter.use(authMiddleware);
statsRouter.get('/aggregate', getStatsAggregate);
