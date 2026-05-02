#!/usr/bin/env node

const fs = require('node:fs');
const path = require('node:path');
const admin = require('firebase-admin');

const [identifier, roleArg = 'admin'] = process.argv.slice(2);
const role = roleArg.toLowerCase();

if (!identifier || !['admin', 'editor'].includes(role)) {
  console.error('Uso: npm run admin:role -- <email-ou-uid> <admin|editor>');
  process.exit(1);
}

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
const projectId = process.env.FIREBASE_PROJECT_ID || 'runnin-494520';

const credential =
  serviceAccountPath && fs.existsSync(serviceAccountPath)
    ? admin.credential.cert(require(path.resolve(serviceAccountPath)))
    : admin.credential.applicationDefault();

admin.initializeApp({ credential, projectId });

async function main() {
  const auth = admin.auth();
  const user = identifier.includes('@')
    ? await auth.getUserByEmail(identifier)
    : await auth.getUser(identifier);

  const existingClaims = user.customClaims || {};
  await auth.setCustomUserClaims(user.uid, {
    ...existingClaims,
    role,
    admin: role === 'admin',
  });

  console.log(`Role "${role}" aplicada para ${user.email || user.uid}.`);
}

main()
  .catch((error) => {
    console.error(error.message || error);
    process.exit(1);
  })
  .finally(() => admin.app().delete());
