import { getFirestore } from '@shared/infra/firebase/firebase.client';
const USER_ID = 'ZDG4s6fnpeYirqWUfKdiLB7MAEJ2';
const PLAN_ID = '8995c66c-aa84-42e8-bd79-a8a60186ba19';
async function main() {
  const db = getFirestore();
  const planDoc = await db.collection('users').doc(USER_ID).collection('plans').doc(PLAN_ID).get();
  const data = planDoc.data() as any;
  console.log('plan.revisions[]:', JSON.stringify(data.revisions, null, 2));
}
main();
