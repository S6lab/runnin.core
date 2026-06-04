import { PlanSession, PlanWeek } from '../domain/plan.entity';
import { RAMP_BASE_FLOOR_KM } from './plan-windows.constants';

/**
 * Defensive layer pós-LLM: garante que o plano gerado respeita os caps
 * REPORTADOS pelo atleta no assessment. Faz CLAMP suave (escala
 * proporcional), não rejeita/regera.
 *
 *  - Cap volume por semana: na semana N (1-based), volume total NÃO pode
 *    exceder `max(RAMP_BASE_FLOOR_KM, currentWeeklyKm) × (1.1 + 0.1 × (N-1))`.
 *    Rampa de 10%/sem (regra dos 10%, Pfitzinger/Daniels). O floor
 *    garante que iniciante absoluto (currentWeeklyKm=2 ou null) ainda
 *    rampa o suficiente pra atingir o peak necessário pra meta — sem
 *    isso o plano de 10K iniciante ficava com sessões de 2-3km eternamente.
 *    Se RACE com peak conhecido (requiredPeakKm), trava no peak quando a
 *    rampa o ultrapassa.
 *
 *  - Sessão-meta (isTarget=true) é PRESERVADA do scaling proporcional
 *    — ela representa a prova e não pode ser reduzida. O ratio é
 *    recalculado sobre o "resto" da semana (todas as outras sessões).
 *
 *  - Cap long run primeiras 4 semanas: se algum Long Run >
 *    capacityDistanceKm × 1.5, clamp pra esse valor. Tipo Long Run
 *    detectado por substring case-insensitive em session.type.
 *    Sessão-meta também isenta aqui (não é Long Run de treino).
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
  // Floor garante que iniciante reportando volume baixo (0-3 km/sem) não
  // fica preso em cap insignificante — a rampa precisa subir de uma base
  // realista pra atingir o peak da meta. Match validateVolumeForGoal.
  const base = Math.max(RAMP_BASE_FLOOR_KM, currentWeeklyKm);
  const cap = base * (RAMP_BASE + RAMP_STEP * weekIdx);
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

  // 1) Cap volume por semana (rampa progressiva) — preservando isTarget.
  // Roda sempre que temos currentWeeklyKm reportado OU sem ele (usa o floor).
  // Antes ficava gated atrás de "currentWeeklyKm > 0", deixando passar planos
  // sem qualquer cap quando o user não informava — abria espaço pra LLM
  // estourar volume sem checagem.
  for (let i = 0; i < out.length; i++) {
    const w = out[i];
    const cap = weeklyCap(inputs.currentWeeklyKm ?? 0, i, inputs.requiredPeakKm);
    const total = sumKm(w);
    if (total > cap && total > 0) {
      // Separa sessão-meta (preservada) das outras (escaláveis). Sem isso,
      // race-day session de 10K virava 3km quando o LLM superdimensionava
      // a semana inteira.
      const targetKm = w.sessions
        .filter(s => s.isTarget === true)
        .reduce((sum, s) => sum + s.distanceKm, 0);
      const scalableTotal = total - targetKm;
      const scalableCap = Math.max(0, cap - targetKm);

      if (scalableTotal <= 0) {
        // Só tem isTarget, nada a escalar.
        continue;
      }

      const ratio = scalableCap / scalableTotal;
      ops.push({
        scope: 'weekly_volume',
        weekNumber: w.weekNumber,
        before: total,
        after: cap,
        ratio,
      });
      for (const s of w.sessions) {
        if (s.isTarget) continue;
        s.distanceKm = round1(s.distanceKm * ratio);
      }
    }
  }

  // 2) Cap long run nas 4 primeiras semanas. Sessão-meta também isenta
  // (não deve aparecer como "Long Run" nas 4 primeiras, mas defensivo).
  if (
    typeof inputs.capacityDistanceKm === 'number' &&
    inputs.capacityDistanceKm > 0
  ) {
    const cap = inputs.capacityDistanceKm * LONG_RUN_HEADROOM;
    for (let i = 0; i < Math.min(out.length, LONG_RUN_WEEKS); i++) {
      const w = out[i];
      for (const s of w.sessions) {
        if (s.isTarget) continue;
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
