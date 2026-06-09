#!/usr/bin/env ts-node

/**
 * Simula o cron de domingo 23h pra week N de um user específico.
 * Roda ApplyWeeklyRevisionUseCase (mesmo caminho do cron de produção):
 *  - puxa runs da semana
 *  - chama LLM (4-block: overload/underload/pace overshoot/undershoot)
 *  - merge → adjustedWeeks
 *  - cria PlanRevision document
 *  - adiciona entry em plan.revisions[] log
 *  - notifica user (push + in-app)
 */

import { container } from '@shared/container';

const USER_ID = 'ZDG4s6fnpeYirqWUfKdiLB7MAEJ2';
const PLAN_ID = '8995c66c-aa84-42e8-bd79-a8a60186ba19';
const WEEK_NUMBER = 1; // semana que acabou no domingo 07-06 (hoje é seg 08, wk2 dia 1)

async function main() {
  const { applyWeeklyRevision } = container.useCases;
  console.log(`Running ApplyWeeklyRevisionUseCase for user=${USER_ID} plan=${PLAN_ID} week=${WEEK_NUMBER}...`);
  const result = await applyWeeklyRevision.execute(USER_ID, PLAN_ID, WEEK_NUMBER);
  console.log('Result:', JSON.stringify(result, null, 2));
}

main().catch((err) => { console.error(err); process.exit(1); });
