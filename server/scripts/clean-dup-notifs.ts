#!/usr/bin/env ts-node
// One-off cleanup das notifs plan_updated duplicadas (TF 56 debug rodou cron 6x hoje).
// Mantém só a mais recente; apaga as outras.
import { getFirestore } from '@shared/infra/firebase/firebase.client';

const USER_ID = 'ZDG4s6fnpeYirqWUfKdiLB7MAEJ2';

async function main() {
  const db = getFirestore();
  const all = await db.collection('users').doc(USER_ID)
    .collection('notifications')
    .get();
  const docs = all.docs
    .filter(d => (d.data() as any).type === 'plan_updated')
    .sort((a, b) => ((b.data() as any).createdAt ?? '').localeCompare((a.data() as any).createdAt ?? ''));
  const snap = { docs, size: docs.length };
  console.log(`Total plan_updated: ${snap.size}`);
  let kept = 0, deleted = 0;
  for (const d of snap.docs) {
    if (kept === 0) {
      console.log(`KEEP ${d.id.slice(0, 50)} createdAt=${(d.data() as any).createdAt?.slice(0, 19)}`);
      kept++;
      continue;
    }
    await d.ref.delete();
    console.log(`DELETE ${d.id.slice(0, 50)} createdAt=${(d.data() as any).createdAt?.slice(0, 19)}`);
    deleted++;
  }
  console.log(`Kept=${kept} Deleted=${deleted}`);
}
main().catch(e => { console.error(e); process.exit(1); });
