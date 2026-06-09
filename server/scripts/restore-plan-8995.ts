#!/usr/bin/env ts-node

/**
 * One-off pra restaurar plan 8995c66c do user ZDG4s6fnpeYirqWUfKdiLB7MAEJ2:
 *  - Apaga revisão órfã (3f3b5b38, criada num plano anterior e re-apontada aqui
 *    em conversa passada — distâncias não batem com a BASE atual deste plano)
 *  - Limpa plan.revisions[] embedded log
 *  - Regenera coachRationale + mesocycleNarrative + goalAssessment via LLM
 *  - Regenera per-week narratives + blockName + objective + targets
 *  - adjustedWeeks fica == weeks (vigent = base; sem revisão aplicada)
 *
 * Uso:
 *   GOOGLE_APPLICATION_CREDENTIALS=./runnin-google-service-account.json \
 *     npx ts-node -r tsconfig-paths/register scripts/restore-plan-8995.ts
 */

import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { getAsyncLLM } from '@shared/infra/llm/llm.factory';

const USER_ID = 'ZDG4s6fnpeYirqWUfKdiLB7MAEJ2';
const PLAN_ID = '8995c66c-aa84-42e8-bd79-a8a60186ba19';
const ORPHAN_REVISION_ID = '3f3b5b38';

async function main(): Promise<void> {
  const db = getFirestore();
  const llm = getAsyncLLM();

  const planRef = db.collection('users').doc(USER_ID).collection('plans').doc(PLAN_ID);
  const planSnap = await planRef.get();
  if (!planSnap.exists) {
    console.error(`Plan ${PLAN_ID} not found`);
    process.exit(1);
  }
  const plan = planSnap.data() as any;
  console.log(`Loaded plan ${PLAN_ID} (status=${plan.status}, weeks=${plan.weeks?.length})`);

  // === 1) Delete orphan revision document ===
  const revsRef = db.collection('users').doc(USER_ID).collection('planRevisions');
  const orphan = await revsRef.where('planId', '==', PLAN_ID).get();
  for (const doc of orphan.docs) {
    if (doc.id.startsWith(ORPHAN_REVISION_ID)) {
      await doc.ref.delete();
      console.log(`Deleted orphan revision ${doc.id}`);
    }
  }

  // === 2) Clear plan.revisions[] log + reset adjustedWeeks == weeks ===
  await planRef.update({
    revisions: [],
    adjustedWeeks: plan.weeks,
    updatedAt: new Date().toISOString(),
  });
  console.log(`Cleared plan.revisions[] + adjustedWeeks reset to base`);

  // === 3) Regenerate rationale ===
  const userSnap = await db.collection('users').doc(USER_ID).get();
  const profile = userSnap.data() as any;
  const weeks = plan.weeks;
  const totalKm = weeks.reduce(
    (s: number, w: any) => s + w.sessions.reduce((ss: number, x: any) => ss + (x.distanceKm ?? 0), 0),
    0,
  );
  const sessionsBySection = weeks
    .map((w: any, i: number) => `Semana ${i + 1}: ${w.sessions.length} sessões / ${w.sessions.reduce((s: number, x: any) => s + x.distanceKm, 0).toFixed(1)}km`)
    .join('\n');
  const profileLines = [
    `- Nome: ${profile?.name ?? '—'}`,
    `- Nível: ${profile?.level ?? '—'}`,
    `- Objetivo: ${profile?.goal ?? '—'}`,
    `- Frequência alvo: ${profile?.frequency ?? '—'}x/semana`,
    `- Período preferido: ${profile?.runPeriod ?? '—'}`,
    `- Idade: ${profile?.birthDate ?? '—'}`,
    `- Peso: ${profile?.weight ?? '—'} | Altura: ${profile?.height ?? '—'}`,
    `- FC repouso: ${profile?.restingBpm ?? '—'} | FC máx: ${profile?.maxBpm ?? '—'}`,
    `- Condições médicas: ${(profile?.medicalConditions ?? []).join(', ') || 'nenhuma'}`,
    `- Wearable conectado: ${profile?.hasWearable ? 'sim' : 'não'}`,
    `- Persona do coach: ${profile?.coachPersonality ?? 'motivador'}`,
  ].join('\n');

  console.log(`Calling LLM for rationale...`);
  const rationalePrompt = `Você é o Coach AI do runnin. Escreva o RACIONAL do plano (markdown, 1000-1400 palavras). Use seções com ## headings exatos: Avaliação do objetivo, Leitura do perfil (verificações + ajustes), Periodização semana a semana, Tipos de sessão neste plano, Recomendações específicas, Como vou adaptar o plano, Limites deste plano. PT-BR, "você" sempre, sem emojis.

# Dados do atleta
${profileLines}

# Plano gerado
- Objetivo: ${plan.goal} / Nível: ${plan.level} / Duração: ${plan.weeksCount} semanas / Volume total: ${totalKm.toFixed(1)}km

${sessionsBySection}

Cada seção: 2-3 parágrafos densos OU 4-6 bullets detalhados. Periodização: liste EXATAMENTE ${plan.weeksCount} bullets ("**Semana N (FASE)** — volume Xkm. Objetivo..."). Recomendações: cite valores reais (peso×0.035L hidratação, etc).`;

  const rationale = await llm.generate(rationalePrompt, {
    systemPrompt: 'Você é o Coach AI do runnin. Tom: técnico, direto. PT-BR.',
    maxTokens: 6000,
    temperature: 0.35,
  });
  console.log(`Rationale: ${rationale.length} chars`);

  // === 4) Regenerate week narratives + goalAssessment + mesocycle ===
  console.log(`Calling LLM for narratives...`);
  const narrPrompt = `Retorne SOMENTE JSON válido pra ${plan.weeksCount} semanas + 1 mesociclo + goalAssessment.

Atleta:
${profileLines}

Estrutura:
${sessionsBySection}

Formato:
{
  "mesocycle": "3-4 frases sobre estratégia do mesociclo todo",
  "goalAssessment": "2-4 frases — avaliação honesta do objetivo (${plan.goal}) pra este perfil",
  "weeks": [
    {"weekNumber": 1, "narrative": "1-2 frases pra esta semana", "blockName": "BASE · ...", "objective": "1 frase", "targets": ["bullet1", "bullet2"]},
    ...
  ]
}`;
  const narrRaw = await llm.generate(narrPrompt, {
    systemPrompt: 'Você é o Coach AI do runnin. Retorne SOMENTE JSON válido.',
    maxTokens: 12000, // gemini 3.5 flash com thinking come tokens — budget folgado
    temperature: 0.4,
    responseJson: true,
  });
  let narr: any;
  try {
    const cleaned = narrRaw.trim().replace(/```(?:json)?/gi, '').replace(/```/g, '').trim();
    narr = JSON.parse(cleaned.slice(cleaned.indexOf('{'), cleaned.lastIndexOf('}') + 1));
  } catch (e) {
    console.error(`Narrative parse failed: ${e}`);
    narr = { mesocycle: '', goalAssessment: '', weeks: [] };
  }

  // Enriquece weeks com as narrativas
  const enriched = weeks.map((w: any) => {
    const match = (narr.weeks ?? []).find((x: any) => x.weekNumber === w.weekNumber);
    if (!match) return w;
    return {
      ...w,
      narrative: match.narrative,
      blockName: match.blockName ?? w.blockName,
      objective: match.objective ?? w.objective,
      targets: match.targets ?? w.targets,
    };
  });

  // === 5) Persist all ===
  await planRef.update({
    coachRationale: rationale.trim(),
    mesocycleNarrative: narr.mesocycle ?? '',
    goalAssessment: narr.goalAssessment ?? '',
    weeks: enriched,
    adjustedWeeks: enriched,
    updatedAt: new Date().toISOString(),
  });
  console.log(`Persisted rationale (${rationale.length} chars) + ${narr.weeks?.length ?? 0} narratives + mesocycle/goalAssessment`);
  console.log(`Done. User should refresh the app.`);
}

main().catch((err) => {
  console.error('Failed:', err);
  process.exit(1);
});
