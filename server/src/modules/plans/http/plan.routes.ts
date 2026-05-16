import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { getCurrentPlan, postGeneratePlan, getPlanById, getPlanKnowledge } from './plan.controller';
import { requestRevisionHandler, listRevisionsHandler } from './plan-revision.controller';
import {
  listWeeklyReportsHandler,
  getWeeklyReportHandler,
  generateWeeklyReportHandler,
} from './weekly-report.controller';

export const planRouter = Router();

planRouter.use(authMiddleware);
planRouter.get('/knowledge/corpus', getPlanKnowledge);
planRouter.get('/current', getCurrentPlan);
planRouter.post('/generate', postGeneratePlan);
planRouter.get('/:id', getPlanById);
planRouter.post('/:id/request-revision', requestRevisionHandler);
planRouter.get('/:id/revisions', listRevisionsHandler);
planRouter.get('/:id/weekly-reports', listWeeklyReportsHandler);
planRouter.get('/:id/weekly-reports/:weekNumber', getWeeklyReportHandler);
planRouter.post('/:id/weekly-reports/:weekNumber/generate', generateWeeklyReportHandler);
