import { getAuth, getFirestore } from '@shared/infra/firebase/firebase.client';
import { logger } from '@shared/logger/logger';

export interface SeedTesterInput {
  /** DDD+número sem prefixo (ex: 11920014380) ou já com +55. */
  phone?: string;
  /** Alternativa: email do user já provisionado. */
  email?: string;
  /** Alternativa: uid Firebase Auth direto. */
  uid?: string;
}

export interface SeedTesterResult {
  uid: string;
  phone: string | null;
  email: string | null;
  claims: Record<string, unknown>;
  profileMerged: boolean;
  biometricSamples: number;
}

/**
 * Provisiona um usuário tester:
 *  - resolve uid via phone/email/uid
 *  - aplica custom claims `{admin: true, tester: true, role: 'admin'}`
 *  - upserta perfil com plano pro + onboarded=true (preserva campos existentes)
 *  - seeda 7d de biometric samples realistas (idempotente)
 */
export class SeedTesterUseCase {
  async execute(input: SeedTesterInput): Promise<SeedTesterResult> {
    const auth = getAuth();
    const db = getFirestore();

    // 1. Resolver uid
    let user: import('firebase-admin/auth').UserRecord;
    if (input.uid) {
      user = await auth.getUser(input.uid);
    } else if (input.email) {
      user = await auth.getUserByEmail(input.email);
    } else if (input.phone) {
      const candidates = input.phone.startsWith('+')
        ? [input.phone]
        : [`+55${input.phone}`, `+${input.phone}`];
      let found: import('firebase-admin/auth').UserRecord | null = null;
      for (const c of candidates) {
        try {
          found = await auth.getUserByPhoneNumber(c);
          break;
        } catch (_) {/* try next */}
      }
      if (!found) {
        throw new Error(`phone ${input.phone} não encontrado (tentei: ${candidates.join(', ')})`);
      }
      user = found;
    } else {
      throw new Error('necessário phone, email ou uid');
    }

    // 2. Custom claims (preserva existentes)
    const existingClaims = user.customClaims ?? {};
    const newClaims = { ...existingClaims, admin: true, tester: true, role: 'admin' };
    await auth.setCustomUserClaims(user.uid, newClaims);
    logger.info('admin.tester.claims_set', { uid: user.uid, claims: newClaims });

    // 3. Upsert profile
    const ref = db.collection('users').doc(user.uid);
    const snap = await ref.get();
    const existing = snap.exists ? snap.data()! : {};
    const now = new Date().toISOString();
    const profile = {
      ...existing,
      name: existing.name ?? `Tester ${(user.phoneNumber ?? user.email ?? user.uid).slice(-4)}`,
      level: existing.level ?? 'intermediario',
      goal: existing.goal ?? 'Manter forma + sub 50min nos 10K',
      frequency: existing.frequency ?? 4,
      gender: existing.gender ?? 'male',
      birthDate: existing.birthDate ?? '1990-01-01',
      weight: existing.weight ?? '72kg',
      height: existing.height ?? '178cm',
      hasWearable: existing.hasWearable ?? true,
      runPeriod: existing.runPeriod ?? 'manha',
      restingBpm: existing.restingBpm ?? 55,
      maxBpm: existing.maxBpm ?? 188,
      medicalConditions: existing.medicalConditions ?? [],
      coachPersonality: existing.coachPersonality ?? 'motivador',
      coachMessageFrequency: existing.coachMessageFrequency ?? 'per_km',
      coachFeedbackEnabled: existing.coachFeedbackEnabled ?? { pace: true, bpm: true, motivation: true },
      notificationsEnabled: existing.notificationsEnabled ?? { push: true, in_app_banner: true },
      onboarded: true,
      lastOnboardingAt: existing.lastOnboardingAt ?? now,
      premium: true,
      subscriptionPlanId: 'pro',
      subscriptionStatus: 'active',
      subscriptionStartedAt: existing.subscriptionStartedAt ?? now,
      updatedAt: now,
    };
    await ref.set(profile, { merge: true });

    // 4. Biometric samples (7d realistas)
    const col = db.collection(`users/${user.uid}/biometric_samples`);
    const nowDate = new Date();
    const receivedAt = nowDate.toISOString();
    const batch = db.batch();
    let count = 0;

    for (let dayOffset = 6; dayOffset >= 0; dayOffset--) {
      const dayDate = new Date(nowDate);
      dayDate.setDate(dayDate.getDate() - dayOffset);
      const morningKey = (() => {
        const d = new Date(dayDate); d.setUTCHours(7, 30, 0, 0); return d.toISOString();
      })();
      const nightKey = (() => {
        const d = new Date(dayDate); d.setUTCHours(23, 0, 0, 0); return d.toISOString();
      })();
      const eveningKey = (() => {
        const d = new Date(dayDate); d.setUTCHours(19, 0, 0, 0); return d.toISOString();
      })();

      const samples = [
        { type: 'sleep_hours',      value: 6.8 + ((dayOffset * 0.21) % 1.4),  unit: 'h',     recordedAt: nightKey   },
        { type: 'resting_bpm',      value: 52 + (dayOffset % 5),              unit: 'bpm',   recordedAt: morningKey },
        { type: 'max_bpm',          value: 175 + ((dayOffset * 3) % 8),       unit: 'bpm',   recordedAt: eveningKey },
        { type: 'steps',            value: 7500 + ((dayOffset * 421) % 4000), unit: 'steps', recordedAt: eveningKey },
        { type: 'hrv',              value: 45 + ((dayOffset * 2) % 15),       unit: 'ms',    recordedAt: morningKey },
        { type: 'calories_burned',  value: 2300 + ((dayOffset * 137) % 600),  unit: 'kcal',  recordedAt: eveningKey },
        { type: 'respiratory_rate', value: 14 + (dayOffset % 4),              unit: 'rpm',   recordedAt: morningKey },
      ];
      for (const s of samples) {
        batch.set(col.doc(`${s.type}_${s.recordedAt}`), {
          ...s, source: 'seed', receivedAt,
        }, { merge: true });
        count++;
      }
    }
    const weightKey = (() => { const d = new Date(nowDate); d.setUTCHours(7, 0, 0, 0); return d.toISOString(); })();
    batch.set(col.doc(`weight_${weightKey}`), {
      type: 'weight', value: 72.4, unit: 'kg', source: 'seed', recordedAt: weightKey, receivedAt,
    }, { merge: true });
    count++;
    await batch.commit();

    return {
      uid: user.uid,
      phone: user.phoneNumber ?? null,
      email: user.email ?? null,
      claims: newClaims,
      profileMerged: true,
      biometricSamples: count,
    };
  }
}
