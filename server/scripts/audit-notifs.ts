#!/usr/bin/env ts-node
import { getFirestore } from '@shared/infra/firebase/firebase.client';

const USER_ID = 'ZDG4s6fnpeYirqWUfKdiLB7MAEJ2';

async function main() {
  const db = getFirestore();
  const snap = await db.collection('users').doc(USER_ID)
    .collection('notifications')
    .orderBy('createdAt', 'desc')
    .limit(60)
    .get();
  console.log(`Total recent: ${snap.size}`);
  const byKey = new Map<string, number>();
  const byType = new Map<string, number>();
  for (const d of snap.docs) {
    const data = d.data() as any;
    const key = `${data.type}|${data.title?.slice(0, 50)}`;
    byKey.set(key, (byKey.get(key) ?? 0) + 1);
    byType.set(data.type, (byType.get(data.type) ?? 0) + 1);
  }
  console.log('\n=== Por (type|title) ===');
  for (const [k, c] of [...byKey.entries()].sort((a, b) => b[1] - a[1])) {
    if (c >= 2) console.log(`  ${c}x ${k}`);
  }
  console.log('\n=== Top 10 recentes ===');
  for (const d of snap.docs.slice(0, 10)) {
    const data = d.data() as any;
    console.log(`  ${data.createdAt?.slice(0, 19)} type=${data.type} id=${d.id.slice(0, 40)}`);
    console.log(`    title="${data.title?.slice(0, 60)}"`);
  }
}
main().catch(e => { console.error(e); process.exit(1); });
