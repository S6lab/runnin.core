import { UserRepository } from '../user.repository';
import { UserProfile } from '../user.entity';

export class ResetPlanRevisionsQuotaUseCase {
  constructor(private repository: UserRepository) {}

  async execute(): Promise<{ resetCount: number }> {
    const batchSize = 100;
    let resetCount = 0;

    while (true) {
      const users: UserProfile[] = await this.repository.list(batchSize);

      if (users.length === 0) {
        break;
      }

      const now = new Date().toISOString();
      const updatePromises = users.map(async (user) => {
        if (!user.planRevisions) return;

        const updated: UserProfile = {
          ...user,
          planRevisions: { usedThisWeek: 0, max: user.planRevisions.max, resetAt: now },
        };
        await this.repository.upsert(updated);
      });

      await Promise.all(updatePromises);
      resetCount += users.length;

      if (users.length < batchSize) {
        break;
      }
    }

    return { resetCount };
  }
}
