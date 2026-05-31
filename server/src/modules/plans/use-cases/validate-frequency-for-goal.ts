import { RunnerLevel } from '@modules/users/domain/user.entity';
import { AppError } from '@shared/errors/app-error';
import {
  BLOCKED_BY_LEVEL,
  MAX_KM_PER_SESSION,
  PEAK_WEEKLY_KM,
  RaceDistanceKm,
  getMinFreqForGoal,
  hasImprovePaceBypass,
} from './plan-windows.constants';

/**
 * Valida 3 dimensões de frequência:
 *  - frequency >= min pra essa combinação (nível × distância) — matriz
 *    em MIN_FREQ_BY_LEVEL_DISTANCE (intermediário roda 21K com freq 3
 *    tranquilo; iniciante precisa de 4 pra distribuir).
 *  - peak_weekly_km / frequency <= max_km_per_session pro nível
 *    (impede empilhar 22km/sessão pra iniciante)
 *  - availableDaysCount >= frequency (revalida o que o FE já gate)
 */
export type ValidateFrequencyResult =
  | { ok: true }
  | {
      ok: false;
      reason: 'below_min_for_distance' | 'session_volume_too_high' | 'available_days_too_few';
      minFrequencyRequired?: number;
      minAvailableDays?: number;
      maxKmPerSession?: number;
      projectedKmPerSession?: number;
    };

export type FrequencyErrorReason =
  | 'below_min_for_distance'
  | 'session_volume_too_high'
  | 'available_days_too_few';

export class FrequencyError extends AppError {
  public readonly reason: FrequencyErrorReason;
  public readonly minFrequencyRequired?: number;
  public readonly minAvailableDays?: number;
  public readonly maxKmPerSession?: number;
  public readonly projectedKmPerSession?: number;

  constructor(
    message: string,
    reason: FrequencyErrorReason,
    extras: {
      minFrequencyRequired?: number;
      minAvailableDays?: number;
      maxKmPerSession?: number;
      projectedKmPerSession?: number;
    } = {},
  ) {
    super(message, 422, 'FREQUENCY_INVALID');
    this.reason = reason;
    this.minFrequencyRequired = extras.minFrequencyRequired;
    this.minAvailableDays = extras.minAvailableDays;
    this.maxKmPerSession = extras.maxKmPerSession;
    this.projectedKmPerSession = extras.projectedKmPerSession;
  }
}

export function validateFrequencyForGoal(
  distance: RaceDistanceKm,
  level: RunnerLevel,
  frequency: number,
  availableDaysCount: number,
  levelHint?: string | null,
  raceMode?: 'complete' | 'improve_pace' | null,
): ValidateFrequencyResult {
  // Bypass total pra improve_pace em (level, distance) elegíveis. Atleta
  // intermediário/avançado escolhendo melhorar pace pode usar qualquer
  // freq — assume responsabilidade pela carga. Iniciante (qualquer
  // subtipo) NÃO tem bypass — segue regras normais.
  if (raceMode === 'improve_pace' && hasImprovePaceBypass(level, distance)) {
    return { ok: true };
  }
  const minFreq = getMinFreqForGoal(level, distance, levelHint);
  // Sentinel = bloqueado por LEVEL, não por freq. Validators de level
  // (validateGoalWindow / _disabledReason) já cobrem; aqui é defensivo.
  if (minFreq >= BLOCKED_BY_LEVEL) {
    return {
      ok: false,
      reason: 'below_min_for_distance',
      minFrequencyRequired: minFreq,
    };
  }
  if (frequency < minFreq) {
    return {
      ok: false,
      reason: 'below_min_for_distance',
      minFrequencyRequired: minFreq,
    };
  }

  if (availableDaysCount > 0 && availableDaysCount < frequency) {
    return {
      ok: false,
      reason: 'available_days_too_few',
      minAvailableDays: frequency,
    };
  }

  const peak = PEAK_WEEKLY_KM[distance];
  if (peak > 0) {
    const projectedKmPerSession = peak / frequency;
    const cap = MAX_KM_PER_SESSION[level];
    if (projectedKmPerSession > cap) {
      // Calcula a freq mínima pra ficar dentro do cap.
      const minFreqByVolume = Math.ceil(peak / cap);
      return {
        ok: false,
        reason: 'session_volume_too_high',
        minFrequencyRequired: minFreqByVolume,
        maxKmPerSession: cap,
        projectedKmPerSession: Math.round(projectedKmPerSession * 10) / 10,
      };
    }
  }

  return { ok: true };
}
