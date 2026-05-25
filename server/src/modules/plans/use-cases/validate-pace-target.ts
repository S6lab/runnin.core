import { RunnerLevel } from '@modules/users/domain/user.entity';
import { AppError } from '@shared/errors/app-error';
import { PACE_IMPROVEMENT_CEILING_PCT } from './plan-windows.constants';

/**
 * Erro estruturado pra pace alvo inviável. Carrega a sugestão de pace
 * factível pra o FE preencher direto no selector.
 */
export class PaceTargetError extends AppError {
  public readonly reason: 'too_ambitious' | 'target_slower';
  public readonly maxImprovementPct: number;
  public readonly suggestedTargetPaceMinKm: string;
  constructor(
    message: string,
    reason: 'too_ambitious' | 'target_slower',
    maxImprovementPct: number,
    suggestedTargetPaceMinKm: string,
  ) {
    super(message, 422, 'PACE_TARGET_INVALID');
    this.reason = reason;
    this.maxImprovementPct = maxImprovementPct;
    this.suggestedTargetPaceMinKm = suggestedTargetPaceMinKm;
  }
}

/**
 * Valida pace alvo (RACE mode improve_pace) contra o ganho máximo factível
 * pelo nível do atleta na janela do plano. Critério: ganho típico de 12
 * semanas escala linear com weeksCount/12 (mais semanas = mais ganho
 * possível, mas não infinito — capamos em 1.5x do ceiling base pra evitar
 * promessa de ganho gigante em 20 semanas).
 */
export type ValidatePaceTargetResult =
  | { ok: true }
  | {
      ok: false;
      reason: 'too_ambitious' | 'target_slower';
      maxImprovementPct: number;
      suggestedTargetPaceMinKm: string;
    };

function parsePace(paceStr: string): number | null {
  const m = paceStr.match(/^(\d{1,2}):(\d{2})$/);
  if (!m) return null;
  return parseInt(m[1], 10) + parseInt(m[2], 10) / 60;
}

function formatPace(minPerKm: number): string {
  const totalSec = Math.round(minPerKm * 60);
  const min = Math.floor(totalSec / 60);
  const sec = totalSec % 60;
  return `${min}:${sec.toString().padStart(2, '0')}`;
}

export function validatePaceTarget(
  currentPace: string,
  targetPace: string,
  level: RunnerLevel,
  weeksCount: number,
): ValidatePaceTargetResult {
  const current = parsePace(currentPace);
  const target = parsePace(targetPace);
  if (current === null || target === null) {
    return { ok: false, reason: 'too_ambitious', maxImprovementPct: 0, suggestedTargetPaceMinKm: currentPace };
  }

  // Target mais lento que atual = sem sentido pra "improve_pace".
  if (target >= current) {
    return {
      ok: false,
      reason: 'target_slower',
      maxImprovementPct: 0,
      suggestedTargetPaceMinKm: currentPace,
    };
  }

  // Ceiling % escalado por weeks (base 12). Cap em 1.5x pra evitar
  // promessas absurdas em plano longo. Floor em 0.5x pra plano curto.
  const baseCeiling = PACE_IMPROVEMENT_CEILING_PCT[level];
  const scaleFactor = Math.max(0.5, Math.min(1.5, weeksCount / 12));
  const maxImprovementPct = baseCeiling * scaleFactor;

  const requestedImprovementPct = ((current - target) / current) * 100;

  if (requestedImprovementPct > maxImprovementPct) {
    // Sugere pace alvo = current * (1 - maxImprovementPct/100)
    const suggestedPaceNum = current * (1 - maxImprovementPct / 100);
    return {
      ok: false,
      reason: 'too_ambitious',
      maxImprovementPct,
      suggestedTargetPaceMinKm: formatPace(suggestedPaceNum),
    };
  }

  return { ok: true };
}
