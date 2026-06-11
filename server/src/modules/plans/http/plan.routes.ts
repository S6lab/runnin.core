import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { requireFeature } from '@shared/infra/http/middlewares/require-feature.middleware';
import { getAdmissibilityConfig, getCurrentPlan, postGeneratePlan, getPlanById, getPlanKnowledge } from './plan.controller';
import { requestRevisionHandler, listRevisionsHandler } from './plan-revision.controller';
import {
  listWeeklyReportsHandler,
  getWeeklyReportHandler,
  generateWeeklyReportHandler,
} from './weekly-report.controller';
import {
  listCheckpoints,
  getCheckpoint,
  getRevisionHandler,
} from './checkpoint.controller';

export const planRouter = Router();

planRouter.use(authMiddleware);
// GET endpoints: livres pra freemium ver estado vazio
planRouter.get('/knowledge/corpus', getPlanKnowledge);
// Antes de '/:id' — senão o param route captura o path.
planRouter.get('/admissibility-config', getAdmissibilityConfig);
planRouter.get('/current', getCurrentPlan);
planRouter.get('/:id', getPlanById);
planRouter.get('/:id/revisions', listRevisionsHandler);
planRouter.get('/:id/revisions/:revisionId', getRevisionHandler);
planRouter.get('/:id/weekly-reports', listWeeklyReportsHandler);
planRouter.get('/:id/weekly-reports/:weekNumber', getWeeklyReportHandler);
planRouter.get('/:id/checkpoints', listCheckpoints);
planRouter.get('/:id/checkpoints/:weekNumber', getCheckpoint);
// POST endpoints (geração + revisão): premium-gated
planRouter.post('/generate', requireFeature('generatePlan'), postGeneratePlan);
planRouter.post('/:id/request-revision', requireFeature('planRevisions'), requestRevisionHandler);
planRouter.post('/:id/weekly-reports/:weekNumber/generate', requireFeature('weeklyReports'), generateWeeklyReportHandler);
// Checkpoint deixou de ter fluxo "solto" pelo app: o feedback agora é
// coletado na ReportPage (PATCH /runs/:id/feedback) e o cron de domingo
// agrega das corridas da semana. Endpoints de submit/skip foram removidos.
// Revisão semanal também é AUTOMÁTICA: o cron aplica direto, sem passo de
// aprovação. Por isso accept/reject também sumiram.
