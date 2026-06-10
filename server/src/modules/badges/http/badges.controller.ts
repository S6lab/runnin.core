import { NextFunction, Request, Response } from 'express';
import { logger } from '@shared/logger/logger';
import { FirestoreRunRepository } from '@modules/runs/infra/firestore-run.repository';
import { FirestoreBadgeRepository } from '../infra/firestore-badge.repository';
import { EvaluateBadgesUseCase } from '../use-cases/evaluate-badges.use-case';

const runs = new FirestoreRunRepository();
const badges = new FirestoreBadgeRepository();
const evaluator = new EvaluateBadgesUseCase(runs, badges);

/** GET /badges/me — lista badges desbloqueados + roda evaluator (retroativo
 *  na 1ª chamada, idempotente nas próximas). */
export async function getMyBadges(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    await evaluator.execute({ uid: req.uid });
    const list = await badges.listByUser(req.uid);
    res.json({ badges: list });
  } catch (err) {
    next(err);
  }
}

/** GET /badges/recent-unseen — pra popup logic (mostra mais recente
 *  ainda não-visto pelo user). Roda evaluator antes (idempotente) pra que
 *  fresh install com histórico antigo veja badges retroativos no boot, sem
 *  precisar abrir /profile/badges primeiro. */
export async function getRecentUnseen(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    await evaluator.execute({ uid: req.uid });
    const list = await badges.listByUser(req.uid);
    const unseen = list.filter((b) => !b.seen);
    res.json({ badges: unseen.slice(0, 5) });
  } catch (err) {
    next(err);
  }
}

/** POST /badges/:id/mark-seen — quando user fecha o popup. */
export async function markBadgeSeen(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const id = req.params['id'] as string | undefined;
    if (!id) {
      res.status(400).json({ error: 'badgeId required' });
      return;
    }
    await badges.markSeen(req.uid, id);
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
}

/** POST /badges/:id/share — incrementa contador. */
export async function trackBadgeShare(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const id = req.params['id'] as string | undefined;
    if (!id) {
      res.status(400).json({ error: 'badgeId required' });
      return;
    }
    await badges.incrementShare(req.uid, id);
    logger.info('badges.shared', { uid: req.uid, badgeId: id });
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
}
