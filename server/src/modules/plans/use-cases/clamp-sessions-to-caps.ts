import { PlanSession, PlanWeek } from '../domain/plan.entity';

/**
 * Defensive layer pós-LLM: garante que o plano gerado respeita os caps
 * REPORTADOS pelo atleta no assessment. Faz CLAMP suave (escala
 * proporcional), não rejeita/regera.
 *
 *  - Cap volume por semana: na semana N (1-based), volume total NÃO pode
 *    exceder `currentWeeklyKm × (1.1 + 0.1 × (N-1))`. Rampa de 10%/sem
 *    (regra dos 10%, Pfitzinger/Daniels). Se RACE com peak conhecido
 *    (requiredPeakKm), trava no peak quando a rampa o ultrapassa.
 *
 *  - Cap long run primeiras 4 semanas: se algum Long Run >
 *    capacityDistanceKm × 1.5, clamp pra esse valor. Tipo Long Run
 *    detectado por substring case-insensitive em session.type.
 *
 * Quando o respectivo input é null, nada é feito (sem referência).
 *
 * Retorna `{ weeks, ops }` — função pura, não muta a entrada.
 */

export interface ClampInputs {
  currentWeeklyKm?: number | null;
  capacityDistanceKm?: number | null;
  /** Pico semanal necessário pra RACE (de validateVolumeForGoal). Trava
   *  absoluta — a rampa nunca passa disso. */
  requiredPeakKm?: number | null;
}

export interface ClampOp {
  scope: 'weekly_volume' | 'long_run_cap';
  weekNumber: number;
  before: number;
  after: number;
  ratio?: number;
}

export interface ClampResult {
  weeks: PlanWeek[];
  ops: ClampOp[];
}

const RAMP_BASE = 1.1; // semana 1: +10%
const RAMP_STEP = 0.1; // +10% por semana extra
const LONG_RUN_HEADROOM = 1.5; // 1.5× distância confortável recente
const LONG_RUN_WEEKS = 4; // só nas 4 primeiras semanas

function isLongRun(session: PlanSession): boolean {
  return session.type.toLowerCase().includes('long');
}

function sumKm(week: PlanWeek): number {
  return week.sessions.reduce((sum, s) => sum + s.distanceKm, 0);
}

/** Cap de volume da semana N (1-based) dado o volume reportado. */
function weeklyCap(currentWeeklyKm: number, weekIdx: number, peak: number | null | undefined): number {
  const cap = currentWeeklyKm * (RAMP_BASE + RAMP_STEP * weekIdx);
  if (typeof peak === 'number' && peak > 0) return Math.min(cap, peak);
  return cap;
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

  // 1) Cap volume por semana (rampa progressiva)
  if (typeof inputs.currentWeeklyKm === 'number' && inputs.currentWeeklyKm > 0) {
    for (let i = 0; i < out.length; i++) {
      const w = out[i];
      const cap = weeklyCap(inputs.currentWeeklyKm, i, inputs.requiredPeakKm);
      const total = sumKm(w);
      if (total > cap && total > 0) {
        const ratio = cap / total;
        ops.push({
          scope: 'weekly_volume',
          weekNumber: w.weekNumber,
          before: total,
          after: cap,
          ratio,
        });
        for (const s of w.sessions) {
          s.distanceKm = round1(s.distanceKm * ratio);
        }
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
