import { getFirestore } from '@shared/infra/firebase/firebase.client';
const USER_ID = 'ZDG4s6fnpeYirqWUfKdiLB7MAEJ2';
async function main() {
  const db = getFirestore();
  const ref = db.collection('users').doc(USER_ID);
  const doc = await ref.get();
  const d = doc.data() as any;
  console.log('before birthDate:', d?.birthDate);
  if (d?.birthDate && /^\d{1,2}\/\d{1,2}\/\d{2,4}$/.test(d.birthDate)) {
    const [dd, mm, yyyy] = d.birthDate.split('/');
    let year = Number(yyyy);
    if (year < 100) year += year < 30 ? 2000 : 1900;
    const iso = `${year}-${mm.padStart(2,'0')}-${dd.padStart(2,'0')}`;
    await ref.update({ birthDate: iso, updatedAt: new Date().toISOString() });
    console.log('migrated to ISO:', iso);
  } else {
    console.log('no migration needed');
  }
}
main().catch(e => { console.error(e); process.exit(1); });
