import { z } from 'zod';
import { UserRepository } from '../user.repository';
import { UserProfile } from '../user.entity';
import { FirestorePlanRepository } from '@modules/plans/infra/firestore-plan.repository';
import { GeneratePlanUseCase } from '@modules/plans/use-cases/generate-plan.use-case';

export const CompleteOnboardingSchema = z.object({
  name: z.string().min(1),
  level: z.enum(['iniciante', 'intermediario', 'avancado']),
  goal: z.string().min(1),
  frequency: z.number().int().min(1).max(7),
  birthDate: z.string().optional(),
  weight: z.string().optional(),
  height: z.string().optional(),
  hasWearable: z.boolean().default(false),
  medicalConditions: z.array(z.string()).default([]),
});

export type CompleteOnboardingInput = z.infer<typeof CompleteOnboardingSchema>;

export class CompleteOnboardingUseCase {
  private planRepo = new FirestorePlanRepository();
  private generatePlan = new GeneratePlanUseCase(this.planRepo);

  constructor(private readonly userRepo: UserRepository) {}

  async execute(userId: string, input: CompleteOnboardingInput): Promise<{ user: UserProfile; planId: string }> {
    const now = new Date().toISOString();

    const profile: UserProfile = {
      id: userId,
      name: input.name,
      level: input.level,
      goal: input.goal,
      frequency: input.frequency,
      birthDate: input.birthDate,
      weight: input.weight,
      height: input.height,
      hasWearable: input.hasWearable,
      medicalConditions: input.medicalConditions,
      coachVoiceId: undefined,
      premium: false,
      onboarded: true,
      createdAt: now,
      updatedAt: now,
    };

    await this.userRepo.upsert(profile);

    const plan = await this.generatePlan.execute(userId, {
      goal: input.goal,
      level: input.level,
      frequency: input.frequency,
    });

    return { user: profile, planId: plan.id };
  }
}
