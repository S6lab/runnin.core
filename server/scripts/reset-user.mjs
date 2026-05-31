import admin from 'firebase-admin';
import { readFileSync } from 'fs';

const key = JSON.parse(readFileSync('/Users/eduardovasqueskaizer/.paperclip/instances/default/secrets/gcp/deploy-sa-key.json', 'utf8'));
admin.initializeApp({ credential: admin.credential.cert(key), projectId: 'runnin-494520' });

const EMAIL = 'eduardokaizer@gmail.com';

const user = await admin.auth().getUserByEmail(EMAIL);
const uid = user.uid;
console.log(`Found uid: ${uid}`);

const db = admin.firestore();

// Delete subcollections
for (const sub of ['plans', 'runs', 'exams', 'rag_chunks', 'coach_messages', 'notifications', 'weekly_reports']) {
  const snap = await db.collection(`users/${uid}/${sub}`).get();
  console.log(`${sub}: deleting ${snap.size} docs`);
  for (const doc of snap.docs) {
    // also try to wipe nested
    const nested = await doc.ref.listCollections();
    for (const c of nested) {
      const n = await c.get();
      for (const nd of n.docs) await nd.ref.delete();
    }
    await doc.ref.delete();
  }
}

// Reset profile
await db.collection('users').doc(uid).set({
  onboarded: false,
  planRevisions: admin.firestore.FieldValue.delete(),
  examsCount: 0,
  coachIntroSeen: false,
  updatedAt: new Date().toISOString(),
}, { merge: true });

// Clear name/level/goal/frequency so onboarding starts clean
await db.collection('users').doc(uid).update({
  name: admin.firestore.FieldValue.delete(),
  level: admin.firestore.FieldValue.delete(),
  goal: admin.firestore.FieldValue.delete(),
  frequency: admin.firestore.FieldValue.delete(),
  birthDate: admin.firestore.FieldValue.delete(),
  weight: admin.firestore.FieldValue.delete(),
  height: admin.firestore.FieldValue.delete(),
  gender: admin.firestore.FieldValue.delete(),
  runPeriod: admin.firestore.FieldValue.delete(),
  wakeTime: admin.firestore.FieldValue.delete(),
  sleepTime: admin.firestore.FieldValue.delete(),
  medicalConditions: admin.firestore.FieldValue.delete(),
}).catch(() => {});

console.log('Reset done.');
process.exit(0);
