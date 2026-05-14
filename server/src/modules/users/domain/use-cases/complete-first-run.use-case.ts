import { UserRepository } from '../user.repository';
import { NotFoundError } from '@shared/errors/app-error';

export class CompleteFirstRunUseCase {
  constructor(private readonly userRepo: UserRepository) {}

  async execute(userId: string): Promise<{ hasCompletedFirstRun: boolean }> {
    const existing = await this.userRepo.findById(userId);
    if (!existing) throw new NotFoundError('User');

    const now = new Date().toISOString();

    const profile = {
      ...existing,
      hasCompletedFirstRun: true,
      updatedAt: now,
    };

    await this.userRepo.upsert(profile);

    return { hasCompletedFirstRun: profile.hasCompletedFirstRun };
  }
}
