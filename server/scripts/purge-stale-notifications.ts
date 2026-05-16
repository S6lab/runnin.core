#!/usr/bin/env ts-node

/**
 * Script one-shot purge de notificações stale no Firestore
 * 
 * Uso:
 *   # Dry-run (default) - lista o que seria deletado
 *   PAPERCLIP_TASK_ID=d643852d-f8b1-4fa7-a9bc-029bc00ad9f9 \
 *   ts-node scripts/purge-stale-notifications.ts --user <userId>
 * 
 *   # Aplica deletions em batch
 *   PAPERCLIP_TASK_ID=d643852d-f8b1-4fa7-a9bc-029bc00ad9f9 \
 *   ts-node scripts/purge-stale-notifications.ts --user <userId> --apply
 * 
 * Descrição:
 * - Lista todos os docs em users/{userId}/notifications
 * - Identifica docs cujo ID não segue o padrão {type}_YYYY-MM-DD (legacy)
 * - Por default, apenas imprime (dry-run)
 * - Com --apply, deleta os docs legacy em batch
 */

import { getFirestore } from '@shared/infra/firebase/firebase.client';

function parseArgs(): { userId: string; apply: boolean } {
  const args = process.argv.slice(2);
  
  let userId = '';
  let apply = false;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--user' && args[i + 1]) {
      userId = args[++i];
    } else if (args[i] === '--apply') {
      apply = true;
    }
  }

  if (!userId) {
    console.error('Uso: ts-node scripts/purge-stale-notifications.ts --user <userId> [--apply]');
    process.exit(1);
  }

  return { userId, apply };
}

// Regex para validar ID de notificação no formato {type}_YYYY-MM-DD
const isValidNotificationId = (id: string): boolean => {
  // Padrão: type_YYYY-MM-DD (ex: daily_2024-12-25, weekly_2024-12-30)
  const pattern = /^[a-z]+_\d{4}-\d{2}-\d{2}$/;
  return pattern.test(id);
};

async function main() {
  const { userId, apply } = parseArgs();

  console.log(`Starting purge for user: ${userId}`);
  console.log(`Mode: ${apply ? 'APPLY (deletions actual)' : 'DRY-RUN (no changes)'}`);
  console.log('---');

  const db = getFirestore();
  const colRef = db.collection(`users/${userId}/notifications`);
  
  const snapshot = await colRef.get();
  
  if (snapshot.empty) {
    console.log(`No notifications found for user ${userId}.`);
    return;
  }

  const legacyDocs: { id: string; data: unknown }[] = [];
  const validCount = snapshot.size;

  snapshot.forEach(doc => {
    const id = doc.id;
    const data = doc.data();
    
    if (!isValidNotificationId(id)) {
      legacyDocs.push({ id, data });
    }
  });

  const totalCount = snapshot.size;
  const legacyCount = legacyDocs.length;
  const validCountAfterFilter = totalCount - legacyCount;

  console.log(`Total notifications: ${totalCount}`);
  console.log(`Valid format (${validCountAfterFilter}): ✅`);
  console.log(`Legacy/Stale (${legacyCount}): ${legacyCount > 0 ? '⚠️' : '✅'}`);

  if (legacyCount === 0) {
    console.log('No legacy notifications to purge.');
    return;
  }

  console.log('\nLegacy documents:');
  legacyDocs.forEach(({ id, data }) => {
    console.log(`  - ${id}`);
    if (data && Object.keys(data).length > 0) {
      console.log(`    Data: ${JSON.stringify(data, null, 2).split('\n').join('\n    ')}`);
    }
  });

  if (!apply) {
    console.log('\n[DRY-RUN] No deletions performed. Add --apply flag to delete.');
    return;
  }

  // Apply mode: batch deletion
  console.log('\nApplying deletions...');
  
  const batch = db.batch();
  legacyDocs.forEach(docRef => {
    batch.delete(colRef.doc(docRef.id));
  });

  try {
    await batch.commit();
    console.log(`Successfully deleted ${legacyCount} legacy notifications.`);
  } catch (error) {
    console.error('Error during batch deletion:', error);
    process.exit(1);
  }
}

main()
  .catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
