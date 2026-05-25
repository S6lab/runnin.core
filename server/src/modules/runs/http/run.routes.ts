import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { postRun, patchGps, patchComplete, patchFeedback, getRun, getRunGps, listRuns } from './run.controller';

export const runRouter = Router();

runRouter.use(authMiddleware);
runRouter.post('/', postRun);
runRouter.get('/', listRuns);
runRouter.get('/:id', getRun);
runRouter.get('/:id/gps', getRunGps);
runRouter.patch('/:id/gps', patchGps);
runRouter.patch('/:id/complete', patchComplete);
// Feedback subjetivo do user pós-corrida (chips do que sentiu/precisou).
// Substitui o fluxo de checkpoint solto — cron de domingo agrega o feedback
// das runs da semana pra propor revisão do plano.
runRouter.patch('/:id/feedback', patchFeedback);
