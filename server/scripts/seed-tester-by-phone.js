#!/usr/bin/env node
/**
 * Provisiona um usuário tester: admin claim + tester claim + perfil pro +
 * 7d de biometric samples seedados.
 *
 * Uso:
 *   node scripts/seed-tester-by-phone.js <ddd-numero-sem-+55>
 *   ex: node scripts/seed-tester-by-phone.js 11920014380
 *
 * Resolve o phone no Firebase Auth (tenta +55<num> e +<num>), seta claims,
 * upserta profile no Firestore e chama o seed biométrico inline. Idempotente.
 */

const fs = require('node:fs');
const path = require('node:path');
const admin = require('firebase-admin');

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'runnin-494520';
const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;

const credential =
  serviceAccountPath && fs.existsSync(serviceAccountPath)
    ? admin.credential.cert(require(path.resolve(serviceAccountPath)))
    : admin.credential.applicationDefault();

admin.initializeApp({ credential, projectId: PROJECT_ID });

const phone = process.argv[2];
if (!phone) {
  console.error('Uso: node scripts/seed-tester-by-phone.js <ddd+num>');
  process.exit(1);
}

async function resolveUid(rawPhone) {
  const candidates = [];
  if (rawPhone.startsWith('+')) candidates.push(rawPhone);
  else {
    candidates.push(`+55${rawPhone}`);
    candidates.push(`+${rawPhone}`);
  }
  for (const candidate of candidates) {
    try {
      const u = await admin.auth().getUserByPhoneNumber(candidate);
      console.log(`✓ encontrado uid=${u.uid} pra ${candidate}`);
      return { uid: u.uid, phone: candidate, email: u.email ?? null };
    } catch (_) {
      // tenta próximo
    }
  }
  throw new Error(`Phone ${rawPhone} não encontrado no Firebase Auth (tentei: ${candidates.join(', ')})`);
}

async function setClaims(uid) {
  const u = await admin.auth().getUser(uid);
  const existing = u.customClaims || {};
  await admin.auth().setCustomUserClaims(uid, {
    ...existing,
    admin: true,
    tester: true,
    role: 'admin',
  });
  console.log(`✓ claims setados em ${uid}: admin + tester`);
}

async function upsertProfile(uid, phone) {
  const db = admin.firestore();
  const ref = db.collection('users').doc(uid);
  const snap = await ref.get();
  const existing = snap.exists ? snap.data() : {};
  const now = new Date().toISOString();
  const profile = {
    ...existing,
    name: existing.name ?? `Tester ${phone.slice(-4)}`,
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
  console.log(`✓ profile upsertado em users/${uid} (subscriptionPlanId=pro, onboarded=true)`);
}

async function seedBiometrics(uid) {
  // Replica a lógica do SeedTestUserUseCase aqui pra rodar sem subir o módulo
  // TS inteiro. Gera 7d de samples realistas.
  const db = admin.firestore();
  const col = db.collection(`users/${uid}/biometric_samples`);
  const now = new Date();
  const receivedAt = now.toISOString();
  const batch = db.batch();
  let count = 0;

  for (let dayOffset = 6; dayOffset >= 0; dayOffset--) {
    const dayDate = new Date(now);
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
      { type: 'sleep_hours',       value: 6.8 + ((dayOffset * 0.21) % 1.4),  unit: 'h',    recordedAt: nightKey },
      { type: 'resting_bpm',       value: 52 + (dayOffset % 5),              unit: 'bpm',  recordedAt: morningKey },
      { type: 'max_bpm',           value: 175 + ((dayOffset * 3) % 8),       unit: 'bpm',  recordedAt: eveningKey },
      { type: 'steps',             value: 7500 + ((dayOffset * 421) % 4000), unit: 'steps',recordedAt: eveningKey },
      { type: 'hrv',               value: 45 + ((dayOffset * 2) % 15),       unit: 'ms',   recordedAt: morningKey },
      { type: 'calories_burned',   value: 2300 + ((dayOffset * 137) % 600),  unit: 'kcal', recordedAt: eveningKey },
      { type: 'respiratory_rate',  value: 14 + (dayOffset % 4),              unit: 'rpm',  recordedAt: morningKey },
    ];
    for (const s of samples) {
      const docId = `${s.type}_${s.recordedAt}`;
      batch.set(col.doc(docId), {
        ...s,
        source: 'seed',
        receivedAt,
      }, { merge: true });
      count++;
    }
  }
  // Weight: 1 sample
  const weightKey = (() => { const d = new Date(now); d.setUTCHours(7, 0, 0, 0); return d.toISOString(); })();
  batch.set(col.doc(`weight_${weightKey}`), {
    type: 'weight', value: 72.4, unit: 'kg', source: 'seed',
    recordedAt: weightKey, receivedAt,
  }, { merge: true });
  count++;

  await batch.commit();
  console.log(`✓ ${count} biometric samples seedados em users/${uid}/biometric_samples`);
}

async function main() {
  const { uid, phone: resolved, email } = await resolveUid(phone);
  await setClaims(uid);
  await upsertProfile(uid, resolved);
  await seedBiometrics(uid);
  console.log(`\n✅ pronto: ${resolved} ${email ? `(${email}) ` : ''}→ uid=${uid}`);
  console.log('   admin: true, tester: true, plan: pro, biométricos: 7d');
}

main()
  .catch((err) => { console.error('❌', err.message || err); process.exit(1); })
  .finally(() => admin.app().delete());
