import { Router } from 'express';
import { getMyBadges, getNext, getRecentUnseen, markBadgeSeen, trackBadgeShare } from './badges.controller';

export const badgesRouter = Router();

badgesRouter.get('/me', getMyBadges);
badgesRouter.get('/recent-unseen', getRecentUnseen);
badgesRouter.get('/next', getNext);
badgesRouter.post('/:id/mark-seen', markBadgeSeen);
badgesRouter.post('/:id/share', trackBadgeShare);
