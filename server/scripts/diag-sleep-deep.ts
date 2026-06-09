import { getFirestore } from '@shared/infra/firebase/firebase.client';
const USER_ID = 'ZDG4s6fnpeYirqWUfKdiLB7MAEJ2';
async function main() {
  const db = getFirestore();
  const sleepTypes = ['sleep_hours', 'sleep_deep', 'sleep_rem', 'sleep_light', 'sleep_in_bed', 'sleep_awake'];
  console.log(`\n=== Sleep samples nos últimos 5d ===`);
  for (const t of sleepTypes) {
    const snap = await db.collection('users').doc(USER_ID)
      .collection('biometric_samples')
      .where('type', '==', t)
      .orderBy('recordedAt', 'desc')
      .limit(5)
      .get();
    console.log(`\n${t}: ${snap.size} samples (top 5 mais recentes)`);
    for (const d of snap.docs) {
      const data = d.data() as any;
      const ctx = data.context || {};
      const dateTo = ctx.dateToUtc ? ` -> ${ctx.dateToUtc.slice(0, 19)}` : '';
      console.log(`  ${data.recordedAt.slice(0,19)}${dateTo}  value=${data.value.toFixed(3)}h  source=${data.source}  src=${ctx.sourceName ?? '-'}`);
    }
  }

  // Aggregate
  console.log(`\n=== Agregado por dia ===`);
  const byDay = new Map<string, any>();
  for (const t of sleepTypes) {
    const snap = await db.collection('users').doc(USER_ID)
      .collection('biometric_samples')
      .where('type', '==', t)
      .where('recordedAt', '>=', '2026-06-01')
      .get();
    for (const d of snap.docs) {
      const data = d.data() as any;
      const day = data.recordedAt.substring(0, 10);
      const e = byDay.get(day) ?? { deep:0, rem:0, light:0, hours:0, inBed:0, awake:0 };
      if (t==='sleep_deep') e.deep += data.value;
      if (t==='sleep_rem') e.rem += data.value;
      if (t==='sleep_light') e.light += data.value;
      if (t==='sleep_hours') e.hours += data.value;
      if (t==='sleep_in_bed') e.inBed += data.value;
      if (t==='sleep_awake') e.awake += data.value;
      byDay.set(day, e);
    }
  }
  for (const [day, e] of [...byDay.entries()].sort((a,b)=>b[0].localeCompare(a[0]))) {
    const stages = e.deep + e.rem + e.light;
    const fallback = Math.max(0, e.inBed - e.awake);
    console.log(`  ${day}: stages=${stages.toFixed(2)}h (D=${e.deep.toFixed(2)} R=${e.rem.toFixed(2)} L=${e.light.toFixed(2)}) | inBed=${e.inBed.toFixed(2)} awake=${e.awake.toFixed(2)} fallback=${fallback.toFixed(2)} | legacy=${e.hours.toFixed(2)}`);
  }
}
main().catch(e => { console.error(e); process.exit(1); });
