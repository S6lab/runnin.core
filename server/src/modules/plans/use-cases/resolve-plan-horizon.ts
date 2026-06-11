/**
 * Fonte única do HORIZONTE do plano: startDate canônico, weeksCount
 * resolvido e âncoras de prova (raceDate/raceDayOfWeek/initialDeadlineAt).
 *
 * Regras:
 *  - raceDate presente ⇒ weeks DERIVADO da data vence `input.weeksCount`
 *    (mismatch loga `plan.horizon.weeks_mismatch`). A prova é soberana —
 *    o plano DEVE terminar nela.
 *  - startDate ausente ⇒ "hoje" na data CIVIL do atleta (tzOffsetMin),
 *    não na data UTC do servidor. Sem tzOffsetMin cai em UTC (legado).
 *  - Anomalias (weeks fora de 4..32, raceDate >365d, raceDate <= start)
 *    logam em HORIZON_STRICT=warn (default) e viram 422 estruturado em
 *    HORIZON_STRICT=enforce.
 */

import { AppError } from '@shared/errors/app-error';
import { logger } from '@shared/logger/logger';
import { isoDateToDayOfWeek } from './race-date.helpers';

export const MIN_PLAN_WEEKS = 4;
export const MAX_PLAN_WEEKS = 32;
export const MAX_RACE_HORIZON_DAYS = 365;

export type PlanHorizonReason =
  | 'invalid_start_date'
  | 'invalid_race_date'
  | 'race_date_not_after_start'
  | 'race_date_too_far'
  | 'weeks_out_of_range';

export class PlanHorizonError extends AppError {
  constructor(
    message: string,
    public readonly reason: PlanHorizonReason,
    public readonly details: Record<string, unknown> = {},
  ) {
    super(message, 422, 'PLAN_HORIZON_INVALID');
  }
}

export interface PlanHorizonInput {
  goalKind?: 'flow' | 'race' | undefined;
  startDate?: string | null | undefined;
  raceDate?: string | null | undefined;
  weeksCount?: number | null | undefined;
  tzOffsetMin?: number | null | undefined;
}

export interface ResolvedPlanHorizon {
  startDate: string;
  /** 1=seg..7=dom, derivado do startDate em UTC. */
  startDayOfWeek: number;
  weeksCount: number;
  raceDate: string | undefined;
  raceDayOfWeek: number | undefined;
  /** Data prevista de conclusão na criação (imutável). */
  initialDeadlineAt: string;
}

function strictMode(): 'warn' | 'enforce' {
  return process.env['HORIZON_STRICT'] === 'enforce' ? 'enforce' : 'warn';
}

/** Data civil (YYYY-MM-DD) do atleta a partir do relógio UTC + offset. */
export function civilDateAtOffset(now: Date, tzOffsetMin: number | null | undefined): string {
  const offset = typeof tzOffsetMin === 'number' ? tzOffsetMin : 0;
  return new Date(now.getTime() + offset * 60_000).toISOString().slice(0, 10);
}

function utcMidnightMs(iso: string): number {
  return new Date(`${iso}T00:00:00Z`).getTime();
}

/** O V8 faz rollover de datas impossíveis (2026-02-31 → 2026-03-03) em
 *  vez de Invalid Date — round-trip pega isso. */
function isRealIsoDate(iso: string): boolean {
  const d = new Date(`${iso}T00:00:00Z`);
  return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === iso;
}

function addDaysIso(iso: string, days: number): string {
  const d = new Date(`${iso}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

function anomaly(
  reason: PlanHorizonReason,
  message: string,
  details: Record<string, unknown>,
): void {
  if (strictMode() === 'enforce') {
    throw new PlanHorizonError(message, reason, details);
  }
  logger.warn('plan.horizon.anomaly', { reason, message, ...details });
}

export function resolvePlanHorizon(
  input: PlanHorizonInput,
  opts: { fallbackWeeks: number; now?: Date },
): ResolvedPlanHorizon {
  const now = opts.now ?? new Date();
  const startDate = input.startDate ?? civilDateAtOffset(now, input.tzOffsetMin);
  if (!isRealIsoDate(startDate)) {
    // Datas que passam no regex do schema mas não existem no calendário
    // (ex: 2026-02-31) — melhor 422 claro que rollover silencioso.
    throw new PlanHorizonError(
      `startDate inválida: ${startDate}`,
      'invalid_start_date',
      { startDate },
    );
  }
  const startDayOfWeek = isoDateToDayOfWeek(startDate);

  const raceDate = input.goalKind === 'race' ? (input.raceDate ?? undefined) : undefined;

  let weeksCount: number;
  let raceDayOfWeek: number | undefined;

  if (raceDate) {
    if (!isRealIsoDate(raceDate)) {
      throw new PlanHorizonError(
        `raceDate inválida: ${raceDate}`,
        'invalid_race_date',
        { raceDate },
      );
    }
    raceDayOfWeek = isoDateToDayOfWeek(raceDate);
    const days = Math.round((utcMidnightMs(raceDate) - utcMidnightMs(startDate)) / 86_400_000);
    if (days <= 0) {
      anomaly(
        'race_date_not_after_start',
        `raceDate (${raceDate}) precisa ser depois do início (${startDate}).`,
        { startDate, raceDate, days },
      );
      // Warn-mode (legado): sem dias positivos não há derivação — cai no
      // input/fallback e o plano NÃO termina na prova. Telemetria acima
      // captura a frequência disso antes do enforce.
      weeksCount = input.weeksCount ?? opts.fallbackWeeks;
      raceDayOfWeek = undefined;
    } else {
      if (days > MAX_RACE_HORIZON_DAYS) {
        anomaly(
          'race_date_too_far',
          `raceDate (${raceDate}) está a ${days} dias — máximo ${MAX_RACE_HORIZON_DAYS}.`,
          { startDate, raceDate, days },
        );
      }
      const derived = Math.ceil(days / 7);
      if (typeof input.weeksCount === 'number' && input.weeksCount !== derived) {
        // A prova é soberana: o derivado VENCE o weeksCount do cliente
        // (antes era o contrário — cliente stale desalinhava o fim do plano).
        logger.warn('plan.horizon.weeks_mismatch', {
          inputWeeks: input.weeksCount,
          derivedWeeks: derived,
          startDate,
          raceDate,
        });
      }
      if (derived < MIN_PLAN_WEEKS || derived > MAX_PLAN_WEEKS) {
        anomaly(
          'weeks_out_of_range',
          `Horizonte de ${derived} semanas fora do range ${MIN_PLAN_WEEKS}..${MAX_PLAN_WEEKS}.`,
          { derivedWeeks: derived, startDate, raceDate },
        );
      }
      weeksCount = derived;
    }
  } else {
    weeksCount = input.weeksCount ?? opts.fallbackWeeks;
  }

  const initialDeadlineAt = (raceDate && raceDayOfWeek !== undefined)
    ? raceDate
    : addDaysIso(startDate, weeksCount * 7 - 1);

  return {
    startDate,
    startDayOfWeek,
    weeksCount,
    raceDate,
    raceDayOfWeek,
    initialDeadlineAt,
  };
}
