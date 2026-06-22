#!/usr/bin/env node
/*
 * dedupe-plan-revisions.js
 *
 * One-shot cleanup do bug do cron weekly-plan-proposals que rodou em
 * 2026-06-21 23:00 BRT com código sem dedup (fix existia em commit
 * 4b24368 mas só foi deployado em 2026-06-22 ~17h).
 *
 * Estratégia: varre `users/*\/plans/*`. Pra cada plano com `revisions[]`
 * contendo `weekNumber` duplicado, mantém a entry com `revisedAt` mais
 * recente (último writer = estado que vigora hoje em adjustedWeeks),
 * remove as outras. NÃO mexe em adjustedWeeks — já é last-writer-wins
 * e re-derivar histórico exato seria especulativo.
 *
 * Uso:
 *   GOOGLE_APPLICATION_CREDENTIALS=/.../runnin-494520-...json \
 *     node server/scripts/dedupe-plan-revisions.js [--apply] [--user <uid>]
 *
 * Sem --apply: dry-run (log no console, não escreve no Firestore).
 * Com --apply: aplica as mudanças.
 * --user <uid>: limita a um único user (debug).
 */

const fs = require('node:fs');
const path = require('node:path');
const admin = require('firebase-admin');

const args = process.argv.slice(2);
const APPLY = args.includes('--apply');
const userIdx = args.indexOf('--user');
const ONLY_USER = userIdx >= 0 ? args[userIdx + 1] : null;

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
const projectId = process.env.FIREBASE_PROJECT_ID || 'runnin-494520';

const credential =
  serviceAccountPath && fs.existsSync(serviceAccountPath)
    ? admin.credential.cert(require(path.resolve(serviceAccountPath)))
    : admin.credential.applicationDefault();

admin.initializeApp({ credential, projectId });

const db = admin.firestore();

function pickWinner(revisionsWithSameWeek) {
  // Mantém a com `revisedAt` (ISO) mais recente; tie-breaker: `weekNumber`
  // (numeric) já é igual, então usa ordem do array (último wins).
  return revisionsWithSameWeek.reduce((winner, current) => {
    const wAt = winner?.revisedAt ?? '';
    const cAt = current?.revisedAt ?? '';
    return cAt > wAt ? current : winner;
  });
}

function dedupeRevisions(revisions) {
  if (!Array.isArray(revisions)) return { deduped: [], dropped: 0 };
  const byWeek = new Map(); // weekNumber → [entries]
  for (const r of revisions) {
    const w = r?.weekNumber;
    if (typeof w !== 'number') continue;
    const arr = byWeek.get(w) ?? [];
    arr.push(r);
    byWeek.set(w, arr);
  }
  let dropped = 0;
  const deduped = [];
  for (const [, arr] of byWeek) {
    if (arr.length === 1) {
      deduped.push(arr[0]);
    } else {
      deduped.push(pickWinner(arr));
      dropped += arr.length - 1;
    }
  }
  // Mantém ordem por weekNumber asc (mais legível pro admin)
  deduped.sort((a, b) => a.weekNumber - b.weekNumber);
  return { deduped, dropped };
}

async function processPlan(userId, planDoc) {
  const data = planDoc.data();
  const revisions = data.revisions ?? [];
  const { deduped, dropped } = dedupeRevisions(revisions);
  if (dropped === 0) return { changed: false };

  const before = revisions.length;
  const after = deduped.length;
  console.log(
    `[user=${userId}] plan=${planDoc.id} revisions ${before}→${after} (drop ${dropped})`,
  );

  if (APPLY) {
    await planDoc.ref.update({
      revisions: deduped,
      updatedAt: new Date().toISOString(),
      backfilledDedupeAt: new Date().toISOString(),
    });
  }
  return { changed: true, dropped };
}

async function processUser(userId) {
  const plansSnap = await db.collection(`users/${userId}/plans`).get();
  if (plansSnap.empty) return { plans: 0, dropped: 0, planDocs: 0, revisionDocsDeleted: 0 };
  let dropped = 0;
  for (const planDoc of plansSnap.docs) {
    const r = await processPlan(userId, planDoc);
    if (r.changed) dropped += r.dropped;
  }
  if (plansSnap.size > 1) {
    const planSummaries = plansSnap.docs.map((d) => {
      const data = d.data();
      return {
        id: d.id,
        status: data.status,
        createdAt: data.createdAt,
        weeksCount: Array.isArray(data.weeks) ? data.weeks.length : 0,
        revisions: Array.isArray(data.revisions) ? data.revisions.length : 0,
      };
    });
    console.log(
      `[user=${userId}] ⚠ ${plansSnap.size} planos coexistem:`,
      JSON.stringify(planSummaries, null, 2),
    );
  }

  // Limpa users/{uid}/planRevisions: agrupa por (planId, weekIndex) e mantém
  // só 1 doc por grupo (o com appliedAt mais recente — mesmo critério do
  // last-writer-wins que o plan.adjustedWeeks já reflete).
  const revisionDocsDeleted = await dedupeRevisionCollection(userId);

  return {
    plans: plansSnap.size,
    dropped,
    planDocs: plansSnap.size,
    revisionDocsDeleted,
  };
}

/** Agrupa por (planId, weekIndex), mantém o de appliedAt mais recente. */
async function dedupeRevisionCollection(userId) {
  const col = db.collection(`users/${userId}/planRevisions`);
  const snap = await col.get();
  if (snap.empty) return 0;

  // groupKey = `${planId}_w${weekIndex}` — mesmo formato do ID determinístico
  // do código novo. Se há 2+ docs com mesmo groupKey, são duplicatas.
  const groups = new Map();
  for (const doc of snap.docs) {
    const d = doc.data();
    const planId = d.planId;
    const weekIndex = d.weekIndex;
    if (!planId || typeof weekIndex !== 'number') continue;
    const key = `${planId}_w${weekIndex}`;
    const arr = groups.get(key) ?? [];
    arr.push({ doc, data: d });
    groups.set(key, arr);
  }

  let deleted = 0;
  for (const [key, entries] of groups) {
    if (entries.length === 1) continue;
    // Prioridade do survivor:
    //   1) doc com id DETERMINÍSTICO `${planId}_w${N}` (matches code novo)
    //   2) doc com appliedAt mais recente
    // Isso garante que o código novo (findById/saveIfAbsent) vai encontrar
    // o doc certo e NÃO criar outro duplicado na próxima execução.
    entries.sort((a, b) => {
      const aDet = a.doc.id === key;
      const bDet = b.doc.id === key;
      if (aDet !== bDet) return aDet ? -1 : 1;
      return (b.data.appliedAt ?? '').localeCompare(a.data.appliedAt ?? '');
    });
    const survivor = entries[0];
    const losers = entries.slice(1);
    console.log(
      `[user=${userId}] planRevisions ${key}: ${entries.length} docs → mantém ${survivor.doc.id} (${survivor.data.appliedAt}), descarta ${losers.length}`,
    );
    if (APPLY) {
      for (const loser of losers) {
        await loser.doc.ref.delete();
        deleted += 1;
      }
    } else {
      deleted += losers.length;
    }
  }
  return deleted;
}

async function main() {
  console.log(
    `[dedupe-plan-revisions] ${APPLY ? 'APPLY' : 'DRY-RUN'}${ONLY_USER ? ` user=${ONLY_USER}` : ''}`,
  );

  if (ONLY_USER) {
    const r = await processUser(ONLY_USER);
    console.log(`done. plans=${r.plans} dropped=${r.dropped}`);
    return;
  }

  // Varre TODOS os users em batches pra evitar segurar lista inteira na memória.
  const usersCol = db.collection('users');
  let cursor = null;
  let totalUsers = 0;
  let totalPlans = 0;
  let totalDropped = 0;
  let affectedUsers = 0;
  let usersWithMultiPlanDocs = 0;
  let totalRevisionDocsDeleted = 0;
  let usersWithDupRevisionDocs = 0;

  while (true) {
    let q = usersCol.orderBy(admin.firestore.FieldPath.documentId()).limit(200);
    if (cursor) q = q.startAfter(cursor);
    const snap = await q.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      const r = await processUser(doc.id);
      totalUsers += 1;
      totalPlans += r.plans;
      if (r.dropped > 0) {
        affectedUsers += 1;
        totalDropped += r.dropped;
      }
      if (r.planDocs > 1) usersWithMultiPlanDocs += 1;
      if (r.revisionDocsDeleted > 0) {
        usersWithDupRevisionDocs += 1;
        totalRevisionDocsDeleted += r.revisionDocsDeleted;
      }
    }
    if (snap.size < 200) break;
    cursor = snap.docs[snap.docs.length - 1];
  }

  console.log(
    `\nResumo:\n  users=${totalUsers} plans=${totalPlans}\n  users_com_2+_plan_docs=${usersWithMultiPlanDocs}\n  users_com_revisions_array_dup=${affectedUsers} revisions_array_dropadas=${totalDropped}\n  users_com_revision_collection_dup=${usersWithDupRevisionDocs} revision_collection_docs_${APPLY ? 'deletados' : 'a_deletar'}=${totalRevisionDocsDeleted}`,
  );
  console.log(APPLY ? 'Aplicado.' : 'Dry-run — passe --apply pra gravar.');
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(() => admin.app().delete());
