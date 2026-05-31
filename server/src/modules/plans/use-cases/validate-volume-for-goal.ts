import {
  PEAK_WEEKLY_KM,
  RAMP_BASE_FLOOR_KM,
  RaceDistanceKm,
  REDIRECT_TARGET,
  WEEKLY_RAMP_RATE,
} from './plan-windows.constants';

/**
 * Valida se o atleta consegue rampar `currentWeeklyKm` até o pico semanal
 * necessário pra essa distância dentro do horizonte do plano.
 *
 * Modelo: crescimento de volume sustentável segue regra dos 10%/semana
 * (Pfitzinger, Daniels). A base inicial é `max(2, currentWeeklyKm)` —
 * isso permite que iniciante de zero (volume null ou muito baixo) ainda
 * cresça via walk-run rápido nas primeiras semanas. O alvo final é
 * `PEAK_WEEKLY_KM[distance]` (pico semanal).
 *
 * Se o alvo não cabe no número de semanas → REDIRECT pra subdistância.
 * Função é IDEMPOTENTE — não muta nada. Chamada DEPOIS de
 * validateGoalWindow no execute() do generate-plan use-case.
 */
export interface ValidateVolumeResult {
  ok: boolean;
  /** Pico semanal necessário pra essa distância. */
  requiredPeakKm: number;
  /** Pico semanal atingível a partir do currentWeeklyKm em weeksCount. */
  rampedToKm: number;
  /** Subdistância sugerida se ok=false. null quando já está em 5K. */
  redirect: RaceDistanceKm | null;
}

export function validateVolumeForGoal(
  currentWeeklyKm: number | null | undefined,
  distance: RaceDistanceKm,
  weeksCount: number,
): ValidateVolumeResult {
  const requiredPeakKm = PEAK_WEEKLY_KM[distance];

  // 5K (ou outra distância com PEAK=0): skip check. Janela mínima já
  // cobre walk-run from zero — iniciante absoluto consegue.
  if (requiredPeakKm <= 0) {
    return { ok: true, requiredPeakKm: 0, rampedToKm: Infinity, redirect: null };
  }

  // Base = floor walk-run (5km/sem é o ponto de partida realista pra
  // qualquer iniciante via walk-run desde sem 1), elevado por
  // currentWeeklyKm quando reportado. Sem essa floor, iniciante absoluto
  // (0 km/sem) fica preso em base=2 e não consegue nem 5K em 12 sem.
  const reported = currentWeeklyKm != null && currentWeeklyKm >= 0 ? currentWeeklyKm : 0;
  const base = Math.max(RAMP_BASE_FLOOR_KM, reported);
  const ramped = base * Math.pow(WEEKLY_RAMP_RATE, weeksCount);

  if (ramped >= requiredPeakKm) {
    return { ok: true, requiredPeakKm, rampedToKm: ramped, redirect: null };
  }
  return {
    ok: false,
    requiredPeakKm,
    rampedToKm: ramped,
    redirect: REDIRECT_TARGET[distance],
  };
}
