import { UserRepository } from '../user.repository';
import { UserProfile } from '../user.entity';
import { NotFoundError } from '@shared/errors/app-error';

const TRIAL_DAYS = 7;

export class ActivateTrialUseCase {
  constructor(private readonly userRepo: UserRepository) {}

  async execute(userId: string): Promise<UserProfile> {
    const profile = await this.userRepo.findById(userId);
    if (!profile) throw new NotFoundError('User');

    const now = Date.now();
    const currentUntil = profile.premiumUntil ? new Date(profile.premiumUntil).getTime() : 0;
    const baseFrom = Math.max(now, currentUntil);
    const newUntil = new Date(baseFrom + TRIAL_DAYS * 24 * 60 * 60 * 1000).toISOString();

    const updated: UserProfile = {
      ...profile,
      premiumUntil: newUntil,
      updatedAt: new Date().toISOString(),
    };
    await this.userRepo.upsert(updated);
    return updated;
  }
}
