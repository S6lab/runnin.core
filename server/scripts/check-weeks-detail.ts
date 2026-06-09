import { getFirestore } from '@shared/infra/firebase/firebase.client';
const USER_ID = 'ZDG4s6fnpeYirqWUfKdiLB7MAEJ2';
const PLAN_ID = '8995c66c-aa84-42e8-bd79-a8a60186ba19';
async function main() {
  const db = getFirestore();
  const plan = (await db.collection('users').doc(USER_ID).collection('plans').doc(PLAN_ID).get()).data() as any;
  console.log('--- ADJUSTED weeks detailLevel ---');
  for (const w of (plan.adjustedWeeks ?? [])) {
    const segs = (w.sessions ?? []).map((s: any) => `${s.type}:${(s.executionSegments?.length ?? 0)}seg/h${s.hydrationLiters ?? '—'}/n${s.nutritionPre ? '✓' : '—'}`);
    console.log(`wk${w.weekNumber} detailLevel=${w.detailLevel ?? 'undefined'} narrative=${w.narrative ? '✓' : '—'} sessions=[${segs.join(', ')}]`);
  }
}
main();
