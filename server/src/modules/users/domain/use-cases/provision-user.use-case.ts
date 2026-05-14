import { z } from 'zod';
import { UserRepository } from '../user.repository';
import { UserProfile } from '../user.entity';

export const ProvisionUserSchema = z.object({
  name: z.string().min(1).optional(),
});

export type ProvisionUserInput = z.infer<typeof ProvisionUserSchema>;

export class ProvisionUserUseCase {
  constructor(private readonly userRepo: UserRepository) {}

  async execute(userId: string, input: ProvisionUserInput = {}): Promise<UserProfile> {
    const existing = await this.userRepo.findById(userId);
    if (existing) return existing;

    const now = new Date().toISOString();
    const profile: UserProfile = {
      id: userId,
      name: input.name?.trim() ?? '',
      level: 'iniciante',
      goal: '',
      frequency: 3,
      birthDate: undefined,
      weight: undefined,
      height: undefined,
      hasWearable: false,
      medicalConditions: [],
      coachVoiceId: undefined,
      premium: false,
      premiumUntil: undefined,
      operatorId: undefined,
      onboarded: false,
      hasCompletedFirstRun: false,
      createdAt: now,
      updatedAt: now,
    };

    await this.userRepo.upsert(profile);
    return profile;
  }
}
