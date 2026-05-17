import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { postRun, patchGps, patchComplete, getRun, getRunGps, listRuns } from './run.controller';

export const runRouter = Router();

runRouter.use(authMiddleware);
runRouter.post('/', postRun);
runRouter.get('/', listRuns);
runRouter.get('/:id', getRun);
runRouter.get('/:id/gps', getRunGps);
runRouter.patch('/:id/gps', patchGps);
runRouter.patch('/:id/complete', patchComplete);
