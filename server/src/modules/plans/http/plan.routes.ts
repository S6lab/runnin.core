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
import {
  listCheckpoints,
  getCheckpoint,
  submitCheckpointInputs,
  skipCheckpointHandler,
  getRevisionHandler,
  acceptProposalHandler,
  rejectProposalHandler,
} from './checkpoint.controller';

export const planRouter = Router();

planRouter.use(authMiddleware);
// GET endpoints: livres pra freemium ver estado vazio
planRouter.get('/knowledge/corpus', getPlanKnowledge);
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
// Checkpoint inputs — registrados durante a semana (sem mudar o plano).
// O plano só é revisado aos domingos (cron) e aplicado no aceite da proposta.
planRouter.post('/:id/checkpoints/:weekNumber/inputs', submitCheckpointInputs);
// "Depois": adia o checkpoint (marca skipped, sem ajuste). Freemium OK.
planRouter.post('/:id/checkpoints/:weekNumber/skip', skipCheckpointHandler);
// Proposta de revisão (gerada pelo cron de domingo): aceitar/recusar — premium.
planRouter.post('/:id/revisions/:revisionId/accept', requireFeature('planRevisions'), acceptProposalHandler);
planRouter.post('/:id/revisions/:revisionId/reject', requireFeature('planRevisions'), rejectProposalHandler);
