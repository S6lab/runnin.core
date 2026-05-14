import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { FirestoreGamificationRepository } from '../infra/firestore-gamification.repository';
import { AwardXpUseCase } from '../domain/use-cases/award-xp.use-case';
import { BADGES, Badge } from '../domain/gamification.entity';

const repo = new FirestoreGamificationRepository();
const awardXp = new AwardXpUseCase(repo);

const AwardXpSchema = z.object({
  xp: z.number().int().positive(),
});

export async function getGamification(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const data = await repo.findByUserId(req.uid);
    if (data) {
      res.json(data);
    } else {
      res.json({
        userId: req.uid,
        totalXp: 0,
        level: 1,
        currentStreak: 0,
        longestStreak: 0,
        lastActivityDate: null,
        unlockedBadges: [],
      });
    }
  } catch (err) { next(err); }
}

export async function postXp(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = AwardXpSchema.parse(req.body);
    const updated = await awardXp.execute(req.uid, input.xp);
    res.json(updated);
  } catch (err) { next(err); }
}

export async function getBadges(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const data = await repo.findByUserId(req.uid);
    const unlockedSet = new Set(data?.unlockedBadges ?? []);

    const badges: Badge[] = Object.values(BADGES).map(badge => ({
      ...badge,
      unlockedAt: unlockedSet.has(badge.id) ? data?.updatedAt : undefined,
    }));

    res.json({ badges });
  } catch (err) { next(err); }
}
