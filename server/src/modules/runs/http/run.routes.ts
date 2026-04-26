import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { postRun, patchGps, patchComplete, getRun, listRuns } from './run.controller';

export const runRouter = Router();

runRouter.use(authMiddleware);
runRouter.post('/', postRun);
runRouter.get('/', listRuns);
runRouter.get('/:id', getRun);
runRouter.patch('/:id/gps', patchGps);
runRouter.patch('/:id/complete', patchComplete);
