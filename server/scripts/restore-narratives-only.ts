#!/usr/bin/env ts-node

// Continuação do restore-plan-8995: só regenera narratives (a 1ª tentativa
// estourou MAX_TOKENS com budget 3000).

import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { getAsyncLLM } from '@shared/infra/llm/llm.factory';

const USER_ID = 'ZDG4s6fnpeYirqWUfKdiLB7MAEJ2';
const PLAN_ID = '8995c66c-aa84-42e8-bd79-a8a60186ba19';

async function main(): Promise<void> {
  const db = getFirestore();
  const llm = getAsyncLLM();
  const planRef = db.collection('users').doc(USER_ID).collection('plans').doc(PLAN_ID);
  const planSnap = await planRef.get();
  const plan = planSnap.data() as any;
  const weeks = plan.weeks;

  const userSnap = await db.collection('users').doc(USER_ID).get();
  const profile = userSnap.data() as any;
  const sessionsBySection = weeks
    .map((w: any, i: number) => `Semana ${i + 1}: ${w.sessions.length} sessões / ${w.sessions.reduce((s: number, x: any) => s + x.distanceKm, 0).toFixed(1)}km`)
    .join('\n');
  const profileLines = [
    `- Nível: ${profile?.level ?? '—'}`,
    `- Objetivo: ${profile?.goal ?? '—'}`,
    `- Idade: ${profile?.birthDate ?? '—'}`,
  ].join('\n');

  const narrPrompt = `Retorne SOMENTE JSON válido. Curto. Pra ${plan.weeksCount} semanas.

Atleta: ${profileLines}
Estrutura:
${sessionsBySection}

JSON:
{
  "mesocycle": "3-4 frases estratégia mesociclo",
  "goalAssessment": "2-4 frases avaliação honesta de '${plan.goal}'",
  "weeks": [
    {"weekNumber": 1, "narrative": "1-2 frases", "blockName": "BASE · Adaptação", "objective": "1 frase", "targets": ["bullet1","bullet2"]},
    ... ${plan.weeksCount} entries total
  ]
}`;

  console.log(`Calling LLM with maxTokens 12000...`);
  const raw = await llm.generate(narrPrompt, {
    systemPrompt: 'Retorne SOMENTE JSON válido. Conciso.',
    maxTokens: 12000,
    temperature: 0.4,
    responseJson: true,
  });
  console.log(`Got ${raw.length} chars`);

  let narr: any;
  try {
    const cleaned = raw.trim().replace(/```(?:json)?/gi, '').replace(/```/g, '').trim();
    const start = cleaned.indexOf('{');
    const end = cleaned.lastIndexOf('}');
    narr = JSON.parse(cleaned.slice(start, end + 1));
  } catch (e) {
    console.error(`Parse failed: ${e}`);
    console.log(`Raw output (first 500):`, raw.slice(0, 500));
    process.exit(1);
  }

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

  await planRef.update({
    mesocycleNarrative: narr.mesocycle ?? '',
    goalAssessment: narr.goalAssessment ?? '',
    weeks: enriched,
    adjustedWeeks: enriched,
    updatedAt: new Date().toISOString(),
  });
  console.log(`Persisted: mesocycle=${(narr.mesocycle ?? '').length} chars, goalAssessment=${(narr.goalAssessment ?? '').length} chars, ${narr.weeks?.length ?? 0} week narratives`);
}

main().catch((err) => { console.error(err); process.exit(1); });
