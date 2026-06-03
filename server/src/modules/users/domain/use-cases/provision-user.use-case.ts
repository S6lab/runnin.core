import { z } from 'zod';
import { UserRepository } from '../user.repository';
import { UserProfile } from '../user.entity';
import { getAuth } from '@shared/infra/firebase/firebase.client';
import { logger } from '@shared/logger/logger';

export const ProvisionUserSchema = z.object({
  name: z.string().min(1).optional(),
});

export type ProvisionUserInput = z.infer<typeof ProvisionUserSchema>;

/**
 * Snapshot do Firebase Auth pra um uid. Lazy: só lê o Auth se precisar
 * (existing user já tem authId/email/phone).
 */
async function fetchAuthSnapshot(userId: string): Promise<{
  email?: string;
  phone?: string;
} | null> {
  try {
    const userRecord = await getAuth().getUser(userId);
    return {
      email: userRecord.email ?? undefined,
      phone: userRecord.phoneNumber ?? undefined,
    };
  } catch (err) {
    logger.warn('users.provision.auth_lookup_failed', {
      userId,
      err: err instanceof Error ? err.message : String(err),
    });
    return null;
  }
}

export class ProvisionUserUseCase {
  constructor(private readonly userRepo: UserRepository) {}

  async execute(userId: string, input: ProvisionUserInput = {}): Promise<UserProfile> {
    const existing = await this.userRepo.findById(userId);
    if (existing) {
      // Top-up: se um user já existente está sem authId/email/phone (criado
      // antes desse campo existir), enriquece a partir do Firebase Auth.
      // Idempotente — se já estiver populado, no-op.
      const needsBackfill =
        !existing.authId || (!existing.email && !existing.phone);
      if (!needsBackfill) return existing;

      const auth = await fetchAuthSnapshot(userId);
      const patch: Partial<UserProfile> = {
        authId: existing.authId ?? userId,
        ...(auth?.email && !existing.email ? { email: auth.email } : {}),
        ...(auth?.phone && !existing.phone ? { phone: auth.phone } : {}),
      };
      await this.userRepo.updatePartial(userId, patch);
      logger.info('users.provision.backfilled', {
        userId,
        fields: Object.keys(patch),
      });
      return { ...existing, ...patch };
    }

    // Novo user — captura email/phone do Firebase Auth.
    const auth = await fetchAuthSnapshot(userId);
    const now = new Date().toISOString();
    const profile: UserProfile = {
      id: userId,
      authId: userId,
      email: auth?.email,
      phone: auth?.phone,
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
      // Subscription: todo novo user nasce freemium
      subscriptionPlanId: 'freemium',
      subscriptionStatus: 'active',
      subscriptionStartedAt: now,
      premium: false,
      operatorId: undefined,
      onboarded: false,
      createdAt: now,
      updatedAt: now,
    };

    if (!profile.email && !profile.phone) {
      logger.warn('users.provision.no_contact', { userId });
    }

    await this.userRepo.upsert(profile);
    return profile;
  }
}
