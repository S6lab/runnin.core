#!/usr/bin/env ts-node

/**
 * One-shot backfill: garante que TODO plano em Firestore tem `adjustedWeeks`
 * inicializado como cópia de `weeks`. A partir daqui, revisões e flags de
 * execução vão pra `adjustedWeeks`, enquanto `weeks` permanece IMUTÁVEL
 * (BASE — exibida só em "VER PLANO BASE").
 *
 * Uso:
 *   # Dry-run (default) — só lista o que faria
 *   ts-node scripts/backfill-adjusted-weeks.ts
 *
 *   # Aplica
 *   ts-node scripts/backfill-adjusted-weeks.ts --apply
 *
 *   # Restringe a um user
 *   ts-node scripts/backfill-adjusted-weeks.ts --user <uid> [--apply]
 */

import { getFirestore } from '@shared/infra/firebase/firebase.client';

interface Args {
  userId?: string;
  apply: boolean;
}

function parseArgs(): Args {
  const args = process.argv.slice(2);
  let userId: string | undefined;
  let apply = false;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--user' && args[i + 1]) {
      userId = args[++i];
    } else if (args[i] === '--apply') {
      apply = true;
    }
  }
  return { userId, apply };
}

async function main(): Promise<void> {
  const { userId, apply } = parseArgs();
  const db = getFirestore();

  const userIds: string[] = userId
    ? [userId]
    : (await db.collection('users').select().get()).docs.map((d) => d.id);

  let scanned = 0;
  let needsBackfill = 0;
  let patched = 0;
  let skipped = 0;

  for (const uid of userIds) {
    const plansSnap = await db.collection('users').doc(uid).collection('plans').get();
    for (const doc of plansSnap.docs) {
      scanned++;
      const data = doc.data() as { weeks?: unknown[]; adjustedWeeks?: unknown[] };
      const hasWeeks = Array.isArray(data.weeks) && data.weeks.length > 0;
      const hasAdjusted = Array.isArray(data.adjustedWeeks) && data.adjustedWeeks.length > 0;
      if (!hasWeeks) {
        skipped++;
        continue;
      }
      if (hasAdjusted) {
        skipped++;
        continue;
      }
      needsBackfill++;
      // eslint-disable-next-line no-console
      console.log(`[${apply ? 'APPLY' : 'DRY'}] plan=${doc.id} user=${uid} weeks=${data.weeks!.length}`);
      if (apply) {
        await doc.ref.update({ adjustedWeeks: data.weeks });
        patched++;
      }
    }
  }

  // eslint-disable-next-line no-console
  console.log(`\nResumo: scanned=${scanned} needsBackfill=${needsBackfill} patched=${patched} skipped=${skipped} mode=${apply ? 'apply' : 'dry-run'}`);
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error('backfill-adjusted-weeks failed:', err);
  process.exit(1);
});
