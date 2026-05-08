import { z } from 'zod';
import { UserRepository } from '../user.repository';
import { UserProfile } from '../user.entity';

export const UpsertProfileSchema = z.object({
  name: z.string().min(1).optional(),
  level: z.enum(['iniciante', 'intermediario', 'avancado']).optional(),
  goal: z.string().optional(),
  frequency: z.number().int().min(1).max(7).optional(),
  birthDate: z.string().optional(),
  weight: z.string().optional(),
  height: z.string().optional(),
  hasWearable: z.boolean().optional(),
  medicalConditions: z.array(z.string()).optional(),
  coachVoiceId: z.enum(['coach-bruno', 'coach-clara', 'coach-luna']).optional(),
  onboarded: z.boolean().optional(),
});

export type UpsertProfileInput = z.infer<typeof UpsertProfileSchema>;

export class UpsertProfileUseCase {
  constructor(private readonly userRepo: UserRepository) {}

  async execute(userId: string, input: UpsertProfileInput): Promise<UserProfile> {
    const existing = await this.userRepo.findById(userId);
    const now = new Date().toISOString();

    const profile: UserProfile = {
      id: userId,
      name: input.name ?? existing?.name ?? '',
      level: input.level ?? existing?.level ?? 'iniciante',
      goal: input.goal ?? existing?.goal ?? '',
      frequency: input.frequency ?? existing?.frequency ?? 3,
      birthDate: input.birthDate ?? existing?.birthDate,
      weight: input.weight ?? existing?.weight,
      height: input.height ?? existing?.height,
      hasWearable: input.hasWearable ?? existing?.hasWearable ?? false,
      medicalConditions: input.medicalConditions ?? existing?.medicalConditions ?? [],
      coachVoiceId: input.coachVoiceId ?? existing?.coachVoiceId,
      premium: existing?.premium ?? false,
      premiumUntil: existing?.premiumUntil,
      lastOnboardingAt: existing?.lastOnboardingAt,
      operatorId: existing?.operatorId,
      onboarded: input.onboarded ?? existing?.onboarded ?? false,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    };

    await this.userRepo.upsert(profile);
    return profile;
  }
}
