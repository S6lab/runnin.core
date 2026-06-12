/**
 * Contador de erros consultável — espelho do runnin-api: todo
 * `logger.error` incrementa `system/errors/daily/{YYYY-MM-DD}` com
 * total + byService + byMessageKey. Aba TECH do admin consome.
 * Best-effort absoluto: import dinâmico (sem ciclo logger↔firebase),
 * falha silenciosa, chaves sanitizadas e capadas.
 */

const SERVICE = 's6-ai';
const MAX_KEYS_PER_DAY = 80;

const seenKeysToday = new Set<string>();
let seenKeysDate = '';

function sanitizeKey(message: string): string {
  const key = message.split(/\s/)[0]?.replace(/[^a-zA-Z0-9._-]/g, '_').slice(0, 80) || 'unknown';
  return key.replace(/\./g, ':');
}

export function recordErrorMetric(message: string): void {
  void (async () => {
    try {
      const today = new Date().toISOString().slice(0, 10);
      if (seenKeysDate !== today) {
        seenKeysDate = today;
        seenKeysToday.clear();
      }
      let key = sanitizeKey(message);
      if (!seenKeysToday.has(key) && seenKeysToday.size >= MAX_KEYS_PER_DAY) {
        key = '_other';
      }
      seenKeysToday.add(key);

      const { getFirestore } = await import('../infra/firebase/firebase.client');
      const { FieldValue } = await import('firebase-admin/firestore');
      await getFirestore()
        .collection('system').doc('errors')
        .collection('daily').doc(today)
        .set(
          {
            date: today,
            total: FieldValue.increment(1),
            [`byService.${SERVICE}`]: FieldValue.increment(1),
            [`byMessageKey.${key}`]: FieldValue.increment(1),
            updatedAt: new Date().toISOString(),
          },
          { merge: true },
        );
    } catch {
      /* contador nunca pode quebrar o fluxo que está logando o erro */
    }
  })();
}
