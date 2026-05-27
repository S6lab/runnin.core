import { PlanSession, PlanWeek } from '../domain/plan.entity';

/**
 * Defensive layer pós-LLM: garante que o plano gerado respeita os caps
 * REPORTADOS pelo atleta no assessment, mesmo se o LLM tiver ignorado as
 * regras duras do prompt. Faz CLAMP suave (escala proporcional), não
 * rejeita/regera.
 *
 *  - Cap volume Semana 1: se sum(distanceKm) > currentWeeklyKm * 1.1, escala
 *    todas as sessões da semana 1 proporcionalmente. Demais semanas ficam,
 *    porque é o LLM que modela a rampa de progressão.
 *
 *  - Cap long run primeiras 4 semanas: se algum Long Run > capacityDistanceKm
 *    * 1.5, clamp pra esse cap. Tipo "Long Run" detectado por substring
 *    case-insensitive em session.type.
 *
 * Quando o respectivo input do atleta é null, nada é feito (sem referência).
 *
 * Retorna `{ weeks, ops }` onde ops descreve cada clamp aplicado pra logger
 * decidir warnar/auditar. Função pura — não muta a entrada.
 */

export interface ClampInputs {
  currentWeeklyKm?: number | null;
  capacityDistanceKm?: number | null;
}

export interface ClampOp {
  scope: 'week1_volume' | 'long_run_cap';
  weekNumber: number;
  before: number;
  after: number;
  ratio?: number;
}

export interface ClampResult {
  weeks: PlanWeek[];
  ops: ClampOp[];
}

const VOLUME_HEADROOM = 1.1; // +10% acima do reportado
const LONG_RUN_HEADROOM = 1.5; // 1.5× distância confortável recente
const LONG_RUN_WEEKS = 4; // só nas 4 primeiras semanas

function isLongRun(session: PlanSession): boolean {
  return session.type.toLowerCase().includes('long');
}

function sumKm(week: PlanWeek): number {
  return week.sessions.reduce((sum, s) => sum + s.distanceKm, 0);
}

export function clampSessionsToCaps(
  weeks: PlanWeek[],
  inputs: ClampInputs,
): ClampResult {
  const ops: ClampOp[] = [];
  const out: PlanWeek[] = weeks.map((w) => ({
    ...w,
    sessions: w.sessions.map((s) => ({ ...s })),
  }));

  // 1) Cap volume semana 1
  if (
    typeof inputs.currentWeeklyKm === 'number' &&
    inputs.currentWeeklyKm > 0 &&
    out.length > 0
  ) {
    const cap = inputs.currentWeeklyKm * VOLUME_HEADROOM;
    const week1 = out[0];
    const total = sumKm(week1);
    if (total > cap && total > 0) {
      const ratio = cap / total;
      ops.push({
        scope: 'week1_volume',
        weekNumber: week1.weekNumber,
        before: total,
        after: cap,
        ratio,
      });
      for (const s of week1.sessions) {
        s.distanceKm = round1(s.distanceKm * ratio);
      }
    }
  }

  // 2) Cap long run nas 4 primeiras semanas
  if (
    typeof inputs.capacityDistanceKm === 'number' &&
    inputs.capacityDistanceKm > 0
  ) {
    const cap = inputs.capacityDistanceKm * LONG_RUN_HEADROOM;
    for (let i = 0; i < Math.min(out.length, LONG_RUN_WEEKS); i++) {
      const w = out[i];
      for (const s of w.sessions) {
        if (isLongRun(s) && s.distanceKm > cap) {
          ops.push({
            scope: 'long_run_cap',
            weekNumber: w.weekNumber,
            before: s.distanceKm,
            after: cap,
          });
          s.distanceKm = round1(cap);
        }
      }
    }
  }

  return { weeks: out, ops };
}

function round1(n: number): number {
  return Math.round(n * 10) / 10;
}
