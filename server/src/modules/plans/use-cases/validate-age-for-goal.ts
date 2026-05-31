import { AppError } from '@shared/errors/app-error';
import { AGE_RESTRICTION_THRESHOLDS, RaceDistanceKm } from './plan-windows.constants';

/**
 * Restrições etárias pra meta de prova. Master 55+ não roda agressivo em
 * maratona; 65+ vai pra safe direto em 42K. Sem `birthDate` → skip.
 */
export type WindowMode = 'aggressive' | 'feasible' | 'safe';

export type ValidateAgeResult =
  | { ok: true }
  | {
      ok: false;
      age: number;
      recommendedMinWindow: 'feasible' | 'safe';
    };

export class AgeRestrictionError extends AppError {
  public readonly age: number;
  public readonly recommendedMinWindow: 'feasible' | 'safe';
  constructor(message: string, age: number, recommendedMinWindow: 'feasible' | 'safe') {
    super(message, 422, 'AGE_RESTRICTION');
    this.age = age;
    this.recommendedMinWindow = recommendedMinWindow;
  }
}

function computeAge(birthDateIso: string, today: Date = new Date()): number | null {
  // Aceita YYYY-MM-DD ou DD/MM/YYYY (formato comum no app).
  let d: Date | null = null;
  if (/^\d{4}-\d{2}-\d{2}/.test(birthDateIso)) {
    d = new Date(`${birthDateIso}T00:00:00Z`);
  } else if (/^\d{2}\/\d{2}\/\d{4}$/.test(birthDateIso)) {
    const [dd, mm, yyyy] = birthDateIso.split('/');
    d = new Date(`${yyyy}-${mm}-${dd}T00:00:00Z`);
  }
  if (!d || Number.isNaN(d.getTime())) return null;
  let age = today.getUTCFullYear() - d.getUTCFullYear();
  const m = today.getUTCMonth() - d.getUTCMonth();
  if (m < 0 || (m === 0 && today.getUTCDate() < d.getUTCDate())) age--;
  return age;
}

export function validateAgeForGoal(
  birthDate: string | undefined | null,
  distance: RaceDistanceKm,
  windowMode: WindowMode,
): ValidateAgeResult {
  if (!birthDate) return { ok: true };
  const age = computeAge(birthDate);
  if (age === null) return { ok: true };

  const { blockAggressiveAge, forceFeasibleHalfAge, forceSafeMarathonAge } =
    AGE_RESTRICTION_THRESHOLDS;

  // 65+ + maratona → só safe.
  if (age >= forceSafeMarathonAge && distance === 42) {
    if (windowMode === 'safe') return { ok: true };
    return { ok: false, age, recommendedMinWindow: 'safe' };
  }

  // 65+ + meia maratona → mínimo feasible.
  if (age >= forceFeasibleHalfAge && distance === 21) {
    if (windowMode === 'feasible' || windowMode === 'safe') return { ok: true };
    return { ok: false, age, recommendedMinWindow: 'feasible' };
  }

  // 55–64 + maratona → mínimo feasible.
  if (age >= blockAggressiveAge && distance === 42) {
    if (windowMode === 'feasible' || windowMode === 'safe') return { ok: true };
    return { ok: false, age, recommendedMinWindow: 'feasible' };
  }

  return { ok: true };
}
