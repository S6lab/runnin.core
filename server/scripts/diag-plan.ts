import { getFirestore } from '@shared/infra/firebase/firebase.client';

async function main() {
  const userId = 'ZDG4s6fnpeYirqWUfKdiLB7MAEJ2';
  const db = getFirestore();
  const plansSnap = await db.collection('users').doc(userId).collection('plans').orderBy('createdAt').get();
  for (const doc of plansSnap.docs) {
    const d = doc.data() as any;
    console.log(`\n========== Plan ${doc.id.slice(0,8)} createdAt=${d.createdAt}`);
    console.log(`status=${d.status} goal=${d.goal} level=${d.level} weeksCount=${d.weeksCount}`);
    console.log(`coachRationale.length=${d.coachRationale?.length ?? 0}`);
    console.log(`revisions[] (log) entries=${d.revisions?.length ?? 0}`);
    // Total per week
    const ws = d.weeks ?? [];
    const aws = d.adjustedWeeks ?? [];
    console.log('Week #  BASE_total  ADJ_total');
    for (let i = 0; i < ws.length; i++) {
      const bt = (ws[i].sessions ?? []).reduce((s: number, x: any) => s + (x.distanceKm ?? 0), 0);
      const at = aws[i] ? (aws[i].sessions ?? []).reduce((s: number, x: any) => s + (x.distanceKm ?? 0), 0) : 0;
      console.log(`  ${String(i+1).padStart(2)}     ${bt.toFixed(1).padStart(5)}km     ${at.toFixed(1).padStart(5)}km${bt === at ? '' : '  ← DIFF'}`);
    }
  }
}
main().catch(e => { console.error(e); process.exit(1); });
