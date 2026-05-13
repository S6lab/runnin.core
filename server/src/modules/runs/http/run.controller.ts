import { Request, Response, NextFunction } from 'express';
import { FirestoreRunRepository } from '../infra/firestore-run.repository';
import { CreateRunUseCase, CreateRunSchema } from '../domain/use-cases/create-run.use-case';
import { AddGpsBatchUseCase, AddGpsBatchSchema } from '../domain/use-cases/add-gps-batch.use-case';
import { CompleteRunUseCase, CompleteRunSchema } from '../domain/use-cases/complete-run.use-case';
import { NotFoundError } from '@shared/errors/app-error';
import { FirestoreGamificationRepository } from '@modules/gamification/infra/firestore-gamification.repository';
import { AwardXpUseCase } from '@modules/gamification/domain/use-cases/award-xp.use-case';
import { CheckBadgeUnlockUseCase } from '@modules/gamification/domain/use-cases/check-badge-unlock.use-case';

const repo = new FirestoreRunRepository();
const gamificationRepo = new FirestoreGamificationRepository();
const createRun = new CreateRunUseCase(repo);
const addGpsBatch = new AddGpsBatchUseCase(repo);
const completeRun = new CompleteRunUseCase(repo);
const awardXp = new AwardXpUseCase(gamificationRepo);
const checkBadgeUnlock = new CheckBadgeUnlockUseCase(gamificationRepo);

export async function postRun(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = CreateRunSchema.parse(req.body);
    const run = await createRun.execute(req.uid, input);
    res.status(201).json(run);
  } catch (err) { next(err); }
}

export async function patchGps(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = AddGpsBatchSchema.parse(req.body);
    const result = await addGpsBatch.execute(req.params['id'] as string, req.uid, input);
    res.json(result);
  } catch (err) { next(err); }
}

export async function patchComplete(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = CompleteRunSchema.parse(req.body);
    const run = await completeRun.execute(req.params['id'] as string, req.uid, input);
    res.json(run);

    // Fire-and-forget: award XP and check badge unlocks after responding
    (async () => {
      try {
        const xp = Math.min(120, Math.max(50, Math.round((run.distanceM ?? 0) / 1000) * 10));
        await awardXp.execute(req.uid, xp);
        const runsCount = await repo.countByUser(req.uid);
        const unlocked = await checkBadgeUnlock.execute(req.uid, run, runsCount);
        if (unlocked.length > 0) {
          console.info(`[gamification] user=${req.uid} unlocked badges: ${unlocked.join(', ')}`);
        }
      } catch (err) {
        console.error('[gamification] post-complete award failed', err);
      }
    })();
  } catch (err) { next(err); }
}

export async function getRun(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const run = await repo.findById(req.params['id'] as string, req.uid);
    if (!run) throw new NotFoundError('Run');
    res.json(run);
  } catch (err) { next(err); }
}

export async function listRuns(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const limit = Math.min(Number(req.query.limit ?? 20), 50);
    const cursor = req.query.cursor as string | undefined;
    const result = await repo.findByUser(req.uid, limit, cursor);
    res.json(result);
  } catch (err) { next(err); }
}
