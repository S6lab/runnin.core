/**
 * Cria/atualiza o usuário de smoke (smoke-bot@s6lab.ai) com senha — o
 * live-smoke autentica via dev-login do runnin-api com essas credenciais.
 *
 * Uso (da pasta server/, que tem firebase-admin + SA key):
 *   GOOGLE_APPLICATION_CREDENTIALS=runnin-google-service-account.json \
 *   SMOKE_PW='...' node ../s6-ai/scripts/create-smoke-user.cjs
 */
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

// Credencial: GOOGLE_APPLICATION_CREDENTIALS ou a SA key do server (gitignored).
if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  const saPath = path.join(__dirname, '..', '..', 'server', 'runnin-google-service-account.json');
  if (fs.existsSync(saPath)) process.env.GOOGLE_APPLICATION_CREDENTIALS = saPath;
}
admin.initializeApp();
const email = process.env.SMOKE_EMAIL || 'smoke-bot@s6lab.ai';
// Senha: SMOKE_PW ou /tmp/smoke-bot-pw.txt (gerado pelo runbook, nunca commitado).
let pw = process.env.SMOKE_PW;
if (!pw) {
  try {
    pw = fs.readFileSync('/tmp/smoke-bot-pw.txt', 'utf8').trim();
  } catch { /* cai no erro abaixo */ }
}
if (!pw) {
  console.error('SMOKE_PW (ou /tmp/smoke-bot-pw.txt) obrigatório');
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
