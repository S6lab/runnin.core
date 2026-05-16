import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { requireFeature } from '@shared/infra/http/middlewares/require-feature.middleware';
import { getCurrentPlan, postGeneratePlan, getPlanById, getPlanKnowledge } from './plan.controller';
import { requestRevisionHandler, listRevisionsHandler } from './plan-revision.controller';
import {
  listWeeklyReportsHandler,
  getWeeklyReportHandler,
  generateWeeklyReportHandler,
} from './weekly-report.controller';

export const planRouter = Router();

planRouter.use(authMiddleware);
// GET endpoints: livres pra freemium ver estado vazio
planRouter.get('/knowledge/corpus', getPlanKnowledge);
planRouter.get('/current', getCurrentPlan);
planRouter.get('/:id', getPlanById);
planRouter.get('/:id/revisions', listRevisionsHandler);
planRouter.get('/:id/weekly-reports', listWeeklyReportsHandler);
planRouter.get('/:id/weekly-reports/:weekNumber', getWeeklyReportHandler);
// POST endpoints (geração + revisão): premium-gated
planRouter.post('/generate', requireFeature('generatePlan'), postGeneratePlan);
planRouter.post('/:id/request-revision', requireFeature('planRevisions'), requestRevisionHandler);
planRouter.post('/:id/weekly-reports/:weekNumber/generate', requireFeature('weeklyReports'), generateWeeklyReportHandler);
