import { NextFunction, Request, Response } from 'express';
import { logger } from '@shared/logger/logger';
import { FirestoreRunRepository } from '@modules/runs/infra/firestore-run.repository';
import { FirestoreBadgeRepository } from '../infra/firestore-badge.repository';
import { EvaluateBadgesUseCase } from '../use-cases/evaluate-badges.use-case';
import { GetNextBadgeUseCase } from '../use-cases/get-next-badge.use-case';

const runs = new FirestoreRunRepository();
const badges = new FirestoreBadgeRepository();
const evaluator = new EvaluateBadgesUseCase(runs, badges);
const getNextBadge = new GetNextBadgeUseCase(runs, badges);

/** GET /badges/me — lista badges desbloqueados + roda evaluator (retroativo
 *  na 1ª chamada, idempotente nas próximas). */
export async function getMyBadges(req: Request, res: Response, next: NextFunction): Promise<void> {
  const t0 = Date.now();
  logger.info('badges.me.start', { uid: req.uid });
  try {
    const evalResult = await evaluator.execute({ uid: req.uid });
    const list = await badges.listByUser(req.uid);
    logger.info('badges.me.ok', {
      uid: req.uid,
      ms: Date.now() - t0,
      total: list.length,
      newlyUnlocked: evalResult.unlocked.length,
    });
    res.json({ badges: list });
  } catch (err) {
    logger.error('badges.me.fail', {
      uid: req.uid,
      ms: Date.now() - t0,
      err: err instanceof Error ? err.message : String(err),
      stack: err instanceof Error ? err.stack : undefined,
    });
    next(err);
  }
}

/** GET /badges/recent-unseen — pra popup logic (mostra mais recente
 *  ainda não-visto pelo user). Roda evaluator antes (idempotente) pra que
 *  fresh install com histórico antigo veja badges retroativos no boot, sem
 *  precisar abrir /profile/badges primeiro. */
export async function getRecentUnseen(req: Request, res: Response, next: NextFunction): Promise<void> {
  const t0 = Date.now();
  logger.info('badges.recent_unseen.start', { uid: req.uid });
  try {
    const evalResult = await evaluator.execute({ uid: req.uid });
    const list = await badges.listByUser(req.uid);
    const unseen = list.filter((b) => !b.seen);
    logger.info('badges.recent_unseen.ok', {
      uid: req.uid,
      ms: Date.now() - t0,
      unseen: unseen.length,
      total: list.length,
      newlyUnlocked: evalResult.unlocked.length,
    });
    res.json({ badges: unseen.slice(0, 5) });
  } catch (err) {
    logger.error('badges.recent_unseen.fail', {
      uid: req.uid,
      ms: Date.now() - t0,
      err: err instanceof Error ? err.message : String(err),
      stack: err instanceof Error ? err.stack : undefined,
    });
    next(err);
  }
}

/** GET /badges/next — calcula o badge mais próximo de desbloquear pra
 *  o teaser permanente da home. Retorna `null` quando user já tem tudo
 *  ou está a < 5% do mais próximo (evita intimidar iniciante). */
export async function getNext(req: Request, res: Response, next: NextFunction): Promise<void> {
  const t0 = Date.now();
  try {
    const next = await getNextBadge.execute(req.uid);
    logger.info('badges.next.ok', {
      uid: req.uid,
      ms: Date.now() - t0,
      badgeId: next?.badgeId ?? null,
      progress: next?.progress ?? null,
    });
    res.json({ next });
  } catch (err) {
    logger.error('badges.next.fail', {
      uid: req.uid,
      ms: Date.now() - t0,
      err: err instanceof Error ? err.message : String(err),
    });
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
    logger.info('badges.mark_seen.ok', { uid: req.uid, badgeId: id });
    res.json({ ok: true });
  } catch (err) {
    logger.error('badges.mark_seen.fail', {
      uid: req.uid,
      badgeId: req.params['id'],
      err: err instanceof Error ? err.message : String(err),
    });
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
    logger.error('badges.share.fail', {
      uid: req.uid,
      badgeId: req.params['id'],
      err: err instanceof Error ? err.message : String(err),
    });
    next(err);
  }
}
