import { AppError } from '@shared/errors/app-error';
import {
  RaceDistanceKm,
  SERIOUS_MEDICAL_KEYWORDS,
} from './plan-windows.constants';

/**
 * Restrições médicas pra meta de prova. Critério:
 *  - Qualquer condição "séria" (cirurgia, hérnia, anticoagulante, etc.)
 *    + distance >= 21 → força safe.
 *  - 3+ comorbidades quaisquer + qualquer race → força safe.
 *
 * Match em substring case+diacritic insensitive contra SERIOUS_MEDICAL_KEYWORDS.
 */
export type WindowMode = 'aggressive' | 'feasible' | 'safe';

export type ValidateMedicalResult =
  | { ok: true }
  | {
      ok: false;
      reason: 'serious_condition' | 'multiple_conditions';
      matchedConditions: string[];
      recommendedWindow: 'safe';
    };

export class MedicalRestrictionError extends AppError {
  public readonly reason: 'serious_condition' | 'multiple_conditions';
  public readonly matchedConditions: string[];
  public readonly recommendedWindow: 'safe';
  constructor(
    message: string,
    reason: 'serious_condition' | 'multiple_conditions',
    matchedConditions: string[],
  ) {
    super(message, 422, 'MEDICAL_RESTRICTION');
    this.reason = reason;
    this.matchedConditions = matchedConditions;
    this.recommendedWindow = 'safe';
  }
}

function normalize(s: string): string {
  return s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
}

function findSerious(conditions: string[]): string[] {
  const matched: string[] = [];
  for (const c of conditions) {
    const norm = normalize(c);
    const hit = SERIOUS_MEDICAL_KEYWORDS.find((kw) => norm.includes(kw));
    if (hit) matched.push(c);
  }
  return matched;
}

export function validateMedicalForGoal(
  medicalConditions: string[] | undefined | null,
  distance: RaceDistanceKm,
  windowMode: WindowMode,
): ValidateMedicalResult {
  const list = (medicalConditions ?? []).filter((c) => c && c.trim().length > 0);
  if (list.length === 0) return { ok: true };

  // Qualquer race + 3+ comorbidades → safe.
  if (list.length >= 3) {
    if (windowMode === 'safe') return { ok: true };
    return {
      ok: false,
      reason: 'multiple_conditions',
      matchedConditions: list,
      recommendedWindow: 'safe',
    };
  }

  // Meta longa (21K+) + condição séria → safe.
  if (distance >= 21) {
    const serious = findSerious(list);
    if (serious.length > 0) {
      if (windowMode === 'safe') return { ok: true };
      return {
        ok: false,
        reason: 'serious_condition',
        matchedConditions: serious,
        recommendedWindow: 'safe',
      };
    }
  }

  return { ok: true };
}
