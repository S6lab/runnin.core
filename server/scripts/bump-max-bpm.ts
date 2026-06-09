import { getFirestore } from '@shared/infra/firebase/firebase.client';
const USER_ID = 'ZDG4s6fnpeYirqWUfKdiLB7MAEJ2';
async function main() {
  const db = getFirestore();
  const ref = db.collection('users').doc(USER_ID);
  // User reportou pico real 165 em corrida recente que app gravou como 150
  // (split.avgBpm.reduce escondia picos curtos). Bumpa profile pra refletir.
  await ref.update({ maxBpm: 165, updatedAt: new Date().toISOString() });
  console.log('maxBpm bumped to 165');
}
main().catch(e => { console.error(e); process.exit(1); });
