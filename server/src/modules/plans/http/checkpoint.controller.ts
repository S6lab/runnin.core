import { Request, Response, NextFunction } from 'express';
import { FirestorePlanCheckpointRepository } from '../infra/firestore-plan-checkpoint.repository';
import { FirestorePlanRevisionRepository } from '../infra/firestore-plan-revision.repository';
import { NotFoundError } from '@shared/errors/app-error';

const checkpointRepo = new FirestorePlanCheckpointRepository();
const revisionRepo = new FirestorePlanRevisionRepository();

function parseWeekNumber(req: Request, res: Response): number | null {
  const wn = Number(req.params['weekNumber']);
  if (!Number.isInteger(wn) || wn < 1) {
    res.status(400).json({ error: 'invalid_week_number' });
    return null;
  }
  return wn;
}

export async function listCheckpoints(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const planId = req.params['id'] as string;
    const items = await checkpointRepo.findByPlan(planId, req.uid);
    res.json({ planId, items });
  } catch (err) {
    next(err);
  }
}

export async function getCheckpoint(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const planId = req.params['id'] as string;
    const weekNumber = parseWeekNumber(req, res);
    if (weekNumber == null) return;
    const cp = await checkpointRepo.findByWeek(planId, weekNumber, req.uid);
    if (!cp) throw new NotFoundError('Checkpoint');
    res.json(cp);
  } catch (err) {
    next(err);
  }
}

/**
 * Detalhe de UMA revisão (do histórico aplicado pelo cron ou manual). Usado
 * no app pra renderizar diff old × new + explicação do coach.
 */
export async function getRevisionHandler(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const planId = req.params['id'] as string;
    const revisionId = req.params['revisionId'] as string;
    const rev = await revisionRepo.findById(revisionId, req.uid);
    if (!rev || rev.planId !== planId) throw new NotFoundError('Revision');
    res.json(rev);
  } catch (err) {
    next(err);
  }
}
