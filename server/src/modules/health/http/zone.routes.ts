import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { requireFeature } from '@shared/infra/http/middlewares/require-feature.middleware';
import { getZonesHandler } from './zone.controller';

export const zoneRouter = Router();

zoneRouter.use(authMiddleware);
zoneRouter.use(requireFeature('healthZones'));
zoneRouter.get('/zones', getZonesHandler);
