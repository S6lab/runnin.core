import { getFirestore } from '@shared/infra/firebase/firebase.client';
const USER_ID = 'ZDG4s6fnpeYirqWUfKdiLB7MAEJ2';
async function main() {
  const db = getFirestore();
  const doc = await db.collection('users').doc(USER_ID).get();
  const d = doc.data() as any;
  console.log('restingBpm:', d?.restingBpm);
  console.log('maxBpm:', d?.maxBpm);
  console.log('birthDate:', d?.birthDate);
  // Latest runs maxBpm
  const runsSnap = await db.collection('users').doc(USER_ID).collection('runs')
    .orderBy('createdAt', 'desc').limit(10).get();
  console.log('\nLast 10 runs maxBpm:');
  for (const r of runsSnap.docs) {
    const rd = r.data() as any;
    console.log(`  ${rd.createdAt?.slice(0, 16)} maxBpm=${rd.maxBpm ?? '-'} distance=${rd.distanceM ? (rd.distanceM/1000).toFixed(2)+'km' : '-'}`);
  }
}
main().catch(e => { console.error(e); process.exit(1); });
