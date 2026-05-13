import { Request, Response, NextFunction } from 'express';
import { FirestoreGamificationRepository } from '../infra/firestore-gamification.repository';

const repo = new FirestoreGamificationRepository();

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
