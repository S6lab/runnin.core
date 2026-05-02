import * as admin from 'firebase-admin';
import { existsSync } from 'fs';
import path from 'path';

let app: admin.app.App;
let firestoreConfigured = false;

export function getFirebaseApp(): admin.app.App {
  if (app) return app;

  const { FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY } =
    process.env;
  const googleApplicationCredentials =
    process.env.GOOGLE_APPLICATION_CREDENTIALS ?? localServiceAccountPath();

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
  } else if (googleApplicationCredentials) {
    // SA key via arquivo (dev local com server-sa-key.json)
    app = admin.initializeApp({
      credential: admin.credential.cert(googleApplicationCredentials),
      projectId: FIREBASE_PROJECT_ID ?? 'runnin-494520',
    });
  } else {
    // ADC: Cloud Run ou gcloud auth application-default login
    app = admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: FIREBASE_PROJECT_ID ?? 'runnin-494520',
    });
  }

  return app;
}

function localServiceAccountPath(): string | undefined {
  const candidate = path.resolve(process.cwd(), 'backend-service-account.json');
  return existsSync(candidate) ? candidate : undefined;
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

export function getStorageBucket(): ReturnType<admin.storage.Storage['bucket']> {
  return getFirebaseApp()
    .storage()
    .bucket(process.env.FIREBASE_STORAGE_BUCKET ?? 'runnin-494520.firebasestorage.app');
}
