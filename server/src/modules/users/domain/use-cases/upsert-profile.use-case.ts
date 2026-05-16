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

  // Identity / demographics
  gender: z.enum(['male', 'female', 'other', 'na']).optional(),

  // Routine
  runPeriod: z.enum(['manha', 'tarde', 'noite']).optional(),
  wakeTime: z.string().regex(/^\d{2}:\d{2}$/).optional(),
  sleepTime: z.string().regex(/^\d{2}:\d{2}$/).optional(),

  // Health metrics
  restingBpm: z.number().optional(),
  maxBpm: z.number().optional(),

  // Coach preferences
  coachIntroSeen: z.boolean().optional(),
  coachPersonality: z.enum(['motivador', 'tecnico', 'sereno']).optional(),
  coachMessageFrequency: z.enum(['per_km', 'per_2km', 'alerts_only', 'silent']).optional(),
  coachFeedbackEnabled: z.record(z.string(), z.boolean()).optional(),

  // PREP alerts
  preRunAlerts: z.record(z.string(), z.boolean()).optional(),

  // Plan revisions quota
  planRevisions: z.object({ usedThisWeek: z.number(), max: z.number(), resetAt: z.string() }).optional(),

  // Notifications
  notificationsEnabled: z.any(),
  dndWindow: z.object({ start: z.string(), end: z.string() }).optional(),

  // Units and formatting
  unitsSystem: z.enum(['metric', 'imperial']).optional(),
  paceFormat: z.enum(['min_per_km', 'min_per_mi']).optional(),
  timeFormat: z.enum(['24h', '12h']).optional(),

  // Subscription (paywall manda subscriptionPlanId='pro' ao assinar)
  subscriptionPlanId: z.enum(['freemium', 'pro']).optional(),
  subscriptionStatus: z.enum(['active', 'cancelled', 'expired', 'trial']).optional(),
  // Legacy: paywall atual ainda manda `premium: true` — aceita e espelha no plan
  premium: z.boolean().optional(),

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

      // Identity / routine
      gender: input.gender ?? existing?.gender,
      runPeriod: input.runPeriod ?? existing?.runPeriod,
      wakeTime: input.wakeTime ?? existing?.wakeTime,
      sleepTime: input.sleepTime ?? existing?.sleepTime,

      // Health metrics
      restingBpm: input.restingBpm ?? existing?.restingBpm,
      maxBpm: input.maxBpm ?? existing?.maxBpm,

      // Coach preferences
      coachIntroSeen: input.coachIntroSeen ?? existing?.coachIntroSeen,
      coachPersonality: input.coachPersonality ?? existing?.coachPersonality,
      coachMessageFrequency: input.coachMessageFrequency ?? existing?.coachMessageFrequency,
      coachFeedbackEnabled: (input.coachFeedbackEnabled as Record<string, boolean> | undefined) ?? existing?.coachFeedbackEnabled,

      // PREP alerts
      preRunAlerts: input.preRunAlerts ?? existing?.preRunAlerts,

      // Notifications
      notificationsEnabled: (input.notificationsEnabled as Record<string, boolean> | undefined) ?? existing?.notificationsEnabled,
      dndWindow: input.dndWindow ?? existing?.dndWindow,

      // Plan revisions quota handling
      planRevisions: (() => {
        const existingRevisions = existing?.planRevisions;
        if (!existingRevisions) return input.planRevisions;
        
        const now = new Date().toISOString();
        if (existingRevisions.resetAt && new Date(existingRevisions.resetAt) < new Date()) {
          return { usedThisWeek: 0, max: existingRevisions.max ?? 1, resetAt: now };
        }
        
        return input.planRevisions ?? existingRevisions;
      })(),
      examsCount: existing?.examsCount,
      
      // Units and formatting
      unitsSystem: input.unitsSystem ?? existing?.unitsSystem,
      paceFormat: input.paceFormat ?? existing?.paceFormat,
      timeFormat: input.timeFormat ?? existing?.timeFormat,
      
      // Subscription handling — espelha legacy `premium` no plan novo
      subscriptionPlanId: (() => {
        if (input.subscriptionPlanId) return input.subscriptionPlanId;
        if (input.premium === true) return 'pro';
        return existing?.subscriptionPlanId ?? 'freemium';
      })(),
      subscriptionStatus: input.subscriptionStatus ?? existing?.subscriptionStatus ?? 'active',
      subscriptionStartedAt: existing?.subscriptionStartedAt ?? now,
      subscriptionRenewsAt: existing?.subscriptionRenewsAt,
      trialEndsAt: existing?.trialEndsAt,
      premium: input.premium ?? existing?.premium ?? false,
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
