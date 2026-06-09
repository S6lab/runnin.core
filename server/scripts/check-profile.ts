import { getFirestore } from '@shared/infra/firebase/firebase.client';
const USER_ID = 'ZDG4s6fnpeYirqWUfKdiLB7MAEJ2';
async function main() {
  const db = getFirestore();
  const doc = await db.collection('users').doc(USER_ID).get();
  const d = doc.data() as any;
  console.log('name:', d?.name);
  console.log('birthDate:', d?.birthDate);
  console.log('age (campo direto):', d?.age);
  if (d?.birthDate) {
    const b = new Date(d.birthDate);
    const ageMs = Date.now() - b.getTime();
    const ageYrs = Math.floor(ageMs / (365.25 * 24 * 60 * 60 * 1000));
    console.log('idade calculada agora:', ageYrs, 'anos');
  }
}
main().catch(e => { console.error(e); process.exit(1); });
