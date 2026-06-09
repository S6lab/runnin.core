#!/usr/bin/env ts-node

/**
 * Limpa a revisão atual + zerar adjustedWeeks pra base do plan 8995.
 * Permite re-rodar simulate-weekly-cron com weekNumber=1 e nova lógica.
 */
import { getFirestore } from '@shared/infra/firebase/firebase.client';

const USER_ID = 'ZDG4s6fnpeYirqWUfKdiLB7MAEJ2';
const PLAN_ID = '8995c66c-aa84-42e8-bd79-a8a60186ba19';

async function main() {
  const db = getFirestore();
  const planRef = db.collection('users').doc(USER_ID).collection('plans').doc(PLAN_ID);
  const planSnap = await planRef.get();
  const plan = planSnap.data() as any;

  // Delete any planRevisions docs pointing to this plan
  const revs = await db.collection('users').doc(USER_ID).collection('planRevisions')
    .where('planId', '==', PLAN_ID).get();
  for (const r of revs.docs) {
    await r.ref.delete();
    console.log(`Deleted revision ${r.id.slice(0,8)}`);
  }

  // Reset plan: clear revisions[], adjustedWeeks = weeks
  await planRef.update({
    revisions: [],
    adjustedWeeks: plan.weeks,
    updatedAt: new Date().toISOString(),
  });
  console.log(`Reset plan ${PLAN_ID.slice(0,8)}: revisions[] cleared, adjustedWeeks = weeks`);
}

main().catch((e) => { console.error(e); process.exit(1); });
