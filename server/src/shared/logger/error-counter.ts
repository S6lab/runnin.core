/**
 * Contador de erros consultável — espelho do padrão do usage-tracker:
 * todo `logger.error` incrementa `system/errors/daily/{YYYY-MM-DD}` com
 * total + byService + byMessageKey. Responde "quantos erros nas últimas
 * 24h, de qual serviço, de que tipo?" sem depender da Cloud Logging API
 * (aba TECH do admin consome).
 *
 * Best-effort absoluto: import dinâmico do Firestore (evita ciclo
 * logger↔firebase.client), falha silenciosa, sanitização da chave.
 */

const SERVICE = 'runnin-api';
/** Cap de chaves distintas por dia — evita doc crescer sem limite quando
 *  uma mensagem carrega id único. Acima do cap, agrega em '_other'. */
const MAX_KEYS_PER_DAY = 80;

const seenKeysToday = new Set<string>();
let seenKeysDate = '';

function sanitizeKey(message: string): string {
  // Chave = primeiro token "tipo evento" (ex: plan.generate.failed). Corta
  // qualquer coisa não-identificadora e limita tamanho (vira field path).
  const key = message.split(/\s/)[0]?.replace(/[^a-zA-Z0-9._-]/g, '_').slice(0, 80) || 'unknown';
  return key.replace(/\./g, ':'); // '.' é separador de field path no Firestore
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
