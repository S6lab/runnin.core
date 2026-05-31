/**
 * Helpers de cálculo em torno da raceDate. Vivem fora do
 * `generate-plan.use-case.ts` pra serem reutilizados pelo enforcer de race-week
 * e pelo builder de revisão (que precisa do dayOfWeek da prova pra falar com
 * o LLM sobre "última sessão da última semana").
 */

import type { GeneratePlanInput } from './generate-plan.use-case';

/**
 * Deriva weeksCount a partir da raceDate (quando RACE + raceDate informados).
 * `ceil((race - start) / 7)` garante que a última semana do plano inclua o
 * dia da prova. Retorna undefined pra fluxos sem raceDate — caller cai no
 * `resolvePlanWeeksCount` legado.
 *
 * NOTA: o resultado ainda é validado contra RACE_WINDOWS via
 * `validateGoalWindow()` no caller. Se a janela for menor que `safe`, o
 * caller bloqueia com GoalWindowError. Aqui não validamos, só calculamos.
 */
export function deriveWeeksCountFromRaceDate(
  input: Pick<GeneratePlanInput, 'goalKind' | 'raceDate'>,
  startDate: string,
): number | undefined {
  if (input.goalKind !== 'race' || !input.raceDate) return undefined;
  const start = new Date(`${startDate}T00:00:00Z`).getTime();
  const race = new Date(`${input.raceDate}T00:00:00Z`).getTime();
  const days = Math.round((race - start) / 86400000);
  if (days <= 0) return undefined;
  return Math.ceil(days / 7);
}

/**
 * Devolve dayOfWeek (1=Mon..7=Sun) pra uma data ISO YYYY-MM-DD.
 * Usado pra ancorar `raceDayOfWeek` no plano + alinhar a sessão-meta
 * no enforce-race-week.
 */
export function isoDateToDayOfWeek(iso: string): number {
  const d = new Date(`${iso}T00:00:00Z`);
  const js = d.getUTCDay(); // 0=Sun..6=Sat
  return js === 0 ? 7 : js;
}
