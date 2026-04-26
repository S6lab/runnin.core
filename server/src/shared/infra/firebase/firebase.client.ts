import * as admin from 'firebase-admin';

let app: admin.app.App;
let firestoreConfigured = false;

export function getFirebaseApp(): admin.app.App {
  if (app) return app;

  const { FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY } = process.env;

  const hasServiceAccount =
    FIREBASE_PROJECT_ID && FIREBASE_CLIENT_EMAIL && FIREBASE_PRIVATE_KEY?.includes('BEGIN');

  if (hasServiceAccount) {
    app = admin.initializeApp({
      credential: admin.credential.cert({
        projectId: FIREBASE_PROJECT_ID!,
        clientEmail: FIREBASE_CLIENT_EMAIL!,
        privateKey: FIREBASE_PRIVATE_KEY!.replace(/\\n/g, '\n'),
      }),
    });
  } else {
    // ADC para dev local com `gcloud auth application-default login`
    app = admin.initializeApp({
      projectId: FIREBASE_PROJECT_ID ?? 'rumo-492120',
    });
  }

  return app;
}

export function getFirestore(): admin.firestore.Firestore {
  const firestore = getFirebaseApp().firestore();
  if (!firestoreConfigured) {
    firestore.settings({ ignoreUndefinedProperties: true });
    firestoreConfigured = true;
  }
  return firestore;
}

export function getAuth(): admin.auth.Auth {
  return getFirebaseApp().auth();
}
