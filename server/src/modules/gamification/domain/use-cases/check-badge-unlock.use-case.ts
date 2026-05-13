import { GamificationRepository } from '../gamification.repository';
import { BadgeId } from '../gamification.entity';
import { Run } from '@modules/runs/domain/run.entity';

export class CheckBadgeUnlockUseCase {
  constructor(private readonly repo: GamificationRepository) {}

  async execute(userId: string, run: Run, allRunsCount: number): Promise<BadgeId[]> {
    const profile = await this.repo.findByUserId(userId);
    const already = new Set(profile?.unlockedBadges ?? []);
    const toUnlock: BadgeId[] = [];

    if (allRunsCount === 1 && !already.has('first_run')) {
      toUnlock.push('first_run');
    }

    if ((profile?.currentStreak ?? 0) >= 7 && !already.has('week_warrior')) {
      toUnlock.push('week_warrior');
    }

    if (run.distanceM >= 42195 && !already.has('marathon_ready')) {
      toUnlock.push('marathon_ready');
    }

    if (run.avgPace && !already.has('speed_demon')) {
      const [min, sec] = run.avgPace.split(':').map(Number);
      const paceSeconds = min * 60 + (sec || 0);
      if (paceSeconds > 0 && paceSeconds < 240) {
        toUnlock.push('speed_demon');
      }
    }

    for (const badgeId of toUnlock) {
      await this.repo.unlockBadge(userId, badgeId);
    }

    return toUnlock;
  }
}
