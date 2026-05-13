import { GamificationRepository } from '../gamification.repository';
import { UserGamification } from '../gamification.entity';

export class AwardXpUseCase {
  constructor(private readonly repo: GamificationRepository) {}

  async execute(userId: string, xp: number): Promise<UserGamification> {
    return this.repo.awardXp(userId, xp);
  }
}
