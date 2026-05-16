import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { requirePremium } from '@shared/infra/http/middlewares/require-premium.middleware';
import { getZonesHandler } from './zone.controller';

export const zoneRouter = Router();

zoneRouter.use(authMiddleware);
zoneRouter.use(requirePremium);
zoneRouter.get('/zones', getZonesHandler);
