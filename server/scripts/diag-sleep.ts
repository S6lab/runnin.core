#!/usr/bin/env ts-node

import { getFirestore } from '@shared/infra/firebase/firebase.client';

const USER_ID = 'ZDG4s6fnpeYirqWUfKdiLB7MAEJ2';

async function main() {
  const db = getFirestore();
  // Hit a wide window: 3 dias atrás
  const from = new Date(Date.now() - 3 * 86_400_000);

  // 1) Samples sleep_* mais recentes
  const types = ['sleep_hours', 'sleep_deep', 'sleep_rem', 'sleep_light'];
  console.log(`\n=== Sleep samples nos últimos 3d ===`);
  for (const t of types) {
    const snap = await db.collection('users').doc(USER_ID)
      .collection('biometric_samples')
      .where('type', '==', t)
      .where('recordedAt', '>=', from.toISOString())
      .orderBy('recordedAt', 'desc')
      .limit(20)
      .get();
    console.log(`\n${t}: ${snap.size} samples`);
    for (const d of snap.docs.slice(0, 5)) {
      const data = d.data();
      console.log(`  recordedAt=${data.recordedAt} value=${data.value} createdAt=${data.createdAt ?? '—'}`);
    }
  }

  // 2) Hit summary endpoint result simulando 7d
  console.log(`\n=== Server summary 7d ===`);
  const samplesSnap = await db.collection('users').doc(USER_ID)
    .collection('biometric_samples')
    .where('type', 'in', types)
    .where('recordedAt', '>=', new Date(Date.now() - 7 * 86_400_000).toISOString())
    .get();
  const byDay = new Map<string, number>();
  for (const d of samplesSnap.docs) {
    const data = d.data() as any;
    const day = (data.recordedAt as string).substring(0, 10);
    byDay.set(day, (byDay.get(day) ?? 0) + data.value);
  }
  const ordered = [...byDay.entries()].sort((a, b) => b[0].localeCompare(a[0]));
  for (const [day, hours] of ordered.slice(0, 7)) {
    console.log(`  ${day}: ${hours.toFixed(2)}h`);
  }
  console.log(`  lastNight (mais recente): ${ordered[0] ? ordered[0][1].toFixed(2) + 'h em ' + ordered[0][0] : 'NONE'}`);
}

main().catch(e => { console.error(e); process.exit(1); });
