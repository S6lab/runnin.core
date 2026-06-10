import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { getCatalog, getMyBadges, getNext, getRecentUnseen, markBadgeSeen, trackBadgeShare } from './badges.controller';

export const badgesRouter = Router();

// TF 79: sem isso req.uid ficava undefined → evaluator rodava sem user
// válido, retornava 0 badges e logs mostravam só `total: 0`. Mesmo padrão
// dos outros routers autenticados (runs/plans/stats).
badgesRouter.use(authMiddleware);

badgesRouter.get('/me', getMyBadges);
badgesRouter.get('/recent-unseen', getRecentUnseen);
badgesRouter.get('/next', getNext);
badgesRouter.get('/catalog', getCatalog);
badgesRouter.post('/:id/mark-seen', markBadgeSeen);
badgesRouter.post('/:id/share', trackBadgeShare);
