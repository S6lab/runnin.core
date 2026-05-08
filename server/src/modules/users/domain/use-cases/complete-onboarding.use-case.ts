import { z } from 'zod';
import { UserRepository } from '../user.repository';
import { UserProfile, isPremium } from '../user.entity';
import { FirestorePlanRepository } from '@modules/plans/infra/firestore-plan.repository';
import { GeneratePlanUseCase } from '@modules/plans/use-cases/generate-plan.use-case';
import { CooldownError, PremiumRequiredError } from '@shared/errors/app-error';

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

function getCooldownDays(): number {
  const raw = Number(process.env.ONBOARDING_COOLDOWN_DAYS);
  return Number.isFinite(raw) && raw >= 0 ? raw : 7;
}

function isProOnly(): boolean {
  return (process.env.ONBOARDING_PRO_ONLY ?? 'false').toLowerCase() === 'true';
}

export class CompleteOnboardingUseCase {
  private planRepo = new FirestorePlanRepository();
  private generatePlan = new GeneratePlanUseCase(this.planRepo);

  constructor(private readonly userRepo: UserRepository) {}

  async execute(userId: string, input: CompleteOnboardingInput): Promise<{ user: UserProfile; planId: string }> {
    const now = new Date().toISOString();
    const existing = await this.userRepo.findById(userId);
    const isRedo = !!existing?.onboarded;

    if (isRedo) {
      const premium = isPremium(existing);
      if (isProOnly() && !premium) {
        throw new PremiumRequiredError('Refazer onboarding está disponível apenas no plano Pro.');
      }
      const cooldownDays = getCooldownDays();
      if (cooldownDays > 0 && existing?.lastOnboardingAt) {
        const last = new Date(existing.lastOnboardingAt).getTime();
        const availableAtMs = last + cooldownDays * 24 * 60 * 60 * 1000;
        if (Date.now() < availableAtMs) {
          throw new CooldownError(
            new Date(availableAtMs).toISOString(),
            `Você poderá refazer o onboarding em breve.`,
          );
        }
      }
      // Snapshot da versão atual antes de sobrescrever
      if (existing) await this.userRepo.archiveOnboarding(userId, existing);
    }

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
      coachVoiceId: existing?.coachVoiceId,
      premium: existing?.premium ?? false,
      premiumUntil: existing?.premiumUntil,
      lastOnboardingAt: now,
      operatorId: existing?.operatorId,
      onboarded: true,
      createdAt: existing?.createdAt ?? now,
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
