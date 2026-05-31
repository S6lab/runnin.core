import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { getStatsAggregate, getStatsBreakdown, getUserTotalsHandler } from './stats.controller';

export const statsRouter = Router();

statsRouter.use(authMiddleware);
statsRouter.get('/aggregate', getStatsAggregate);
statsRouter.get('/breakdown', getStatsBreakdown);
statsRouter.get('/totals', getUserTotalsHandler);
