/**
 * Cria/atualiza o usuário de smoke (smoke-bot@s6lab.ai) com senha — o
 * live-smoke autentica via dev-login do runnin-api com essas credenciais.
 *
 * Uso (da pasta server/, que tem firebase-admin + SA key):
 *   GOOGLE_APPLICATION_CREDENTIALS=runnin-google-service-account.json \
 *   SMOKE_PW='...' node ../s6-ai/scripts/create-smoke-user.cjs
 */
const admin = require('firebase-admin');

admin.initializeApp();
const email = process.env.SMOKE_EMAIL || 'smoke-bot@s6lab.ai';
const pw = process.env.SMOKE_PW;
if (!pw) {
  console.error('SMOKE_PW obrigatório');
  process.exit(1);
}

admin.auth().getUserByEmail(email)
  .then((u) => admin.auth().updateUser(u.uid, { password: pw }).then(() => {
    console.log('updated', u.uid);
  }))
  .catch(() => admin.auth().createUser({ email, password: pw, displayName: 'Smoke Bot' }).then((u) => {
    console.log('created', u.uid);
  }))
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(String(err));
    process.exit(1);
  });
