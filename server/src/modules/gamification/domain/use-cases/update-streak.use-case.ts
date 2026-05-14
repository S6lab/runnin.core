import { GamificationRepository } from '../gamification.repository';
import { UserGamification } from '../gamification.entity';

export class UpdateStreakUseCase {
  constructor(private readonly repo: GamificationRepository) {}

  async execute(userId: string): Promise<UserGamification> {
    // Streak is automatically updated when awarding XP (in awardXp method)
    // This use case delegates to awardXp with 0 XP just to trigger streak calculation
    return this.repo.awardXp(userId, 0);
  }
}
