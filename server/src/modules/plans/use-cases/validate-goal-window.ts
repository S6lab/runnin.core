import { RunnerLevel } from '@modules/users/domain/user.entity';
import { AppError } from '@shared/errors/app-error';
import {
  RACE_WINDOWS,
  REDIRECT_TARGET,
  RaceDistanceKm,
  getWindowWeeks,
} from './plan-windows.constants';

/**
 * Erro estruturado pra meta inviável. O FE renderiza tela de REDIRECT
 * quando reason='requires_redirect' (com payload.redirect.distanceKm +
 * suggestedWeeks). Quando reason='too_aggressive', mostra tooltip "mínimo
 * é minWeeks semanas".
 */
export class GoalWindowError extends AppError {
  public readonly reason: 'requires_redirect' | 'too_aggressive';
  public readonly minWeeks?: number;
  public readonly redirect?: { distanceKm: RaceDistanceKm; suggestedWeeks: number };
  constructor(
    message: string,
    reason: 'requires_redirect' | 'too_aggressive',
    extras: {
      minWeeks?: number;
      redirect?: { distanceKm: RaceDistanceKm; suggestedWeeks: number };
    },
  ) {
    super(message, 422, 'GOAL_WINDOW_INVALID');
    this.reason = reason;
    this.minWeeks = extras.minWeeks;
    this.redirect = extras.redirect;
  }
}

/**
 * Valida combinação (distância × nível × weeksCount) contra a tabela de
 * janelas. Três resultados possíveis:
 *  - ok=true: combinação dentro de alguma janela (agressivo/factível/seguro).
 *  - ok=false reason=requires_redirect: nem a janela seguro permite essa
 *    distância pro nível — sugere subdistância (ex: iniciante+maratona).
 *  - ok=false reason=too_aggressive: weeksCount abaixo do mínimo factível
 *    pra essa distância+nível. Sugere weeksCount mínimo.
 */
export type ValidateGoalWindowResult =
  | { ok: true; matchedMode: 'aggressive' | 'feasible' | 'safe' }
  | {
      ok: false;
      reason: 'requires_redirect';
      redirect: { distanceKm: RaceDistanceKm; suggestedWeeks: number } | null;
    }
  | {
      ok: false;
      reason: 'too_aggressive';
      minWeeks: number;
    };

export function validateGoalWindow(
  distance: RaceDistanceKm,
  level: RunnerLevel,
  weeksCount: number,
): ValidateGoalWindowResult {
  const entry = RACE_WINDOWS[distance][level];

  // Se o ÚNICO modo disponível é safe (agressivo + factível = null),
  // tolera weeksCount apenas se >= safe. Senão REDIRECT.
  if (entry.aggressive === null && entry.feasible === null) {
    if (weeksCount >= entry.safe) return { ok: true, matchedMode: 'safe' };
    const target = REDIRECT_TARGET[distance];
    if (target === null) {
      // Distância já é a menor — não tem onde redirecionar. Forçar safe.
      return { ok: false, reason: 'too_aggressive', minWeeks: entry.safe };
    }
    const subEntry = RACE_WINDOWS[target][level];
    return {
      ok: false,
      reason: 'requires_redirect',
      redirect: { distanceKm: target, suggestedWeeks: subEntry.feasible ?? subEntry.safe },
    };
  }

  // Cabe em algum dos 3 modos?
  if (weeksCount >= entry.safe) return { ok: true, matchedMode: 'safe' };
  if (entry.feasible !== null && weeksCount >= entry.feasible) {
    return { ok: true, matchedMode: 'feasible' };
  }
  if (entry.aggressive !== null && weeksCount >= entry.aggressive) {
    return { ok: true, matchedMode: 'aggressive' };
  }

  // Abaixo do mínimo factível.
  const minWeeks = getMinWeeks(distance, level);
  return { ok: false, reason: 'too_aggressive', minWeeks };
}

function getMinWeeks(distance: RaceDistanceKm, level: RunnerLevel): number {
  const entry = RACE_WINDOWS[distance][level];
  return entry.aggressive ?? entry.feasible ?? entry.safe;
}

/** Helper pra FE renderizar opções disponíveis com semanas. */
export function getAvailableWindows(distance: RaceDistanceKm, level: RunnerLevel): {
  mode: 'aggressive' | 'feasible' | 'safe';
  weeks: number;
}[] {
  const out: { mode: 'aggressive' | 'feasible' | 'safe'; weeks: number }[] = [];
  for (const mode of ['aggressive', 'feasible', 'safe'] as const) {
    const w = getWindowWeeks(distance, level, mode);
    if (w !== null) out.push({ mode, weeks: w });
  }
  return out;
}
