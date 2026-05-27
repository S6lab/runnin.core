import { PlanWeek } from '../domain/plan.entity';

/**
 * Defensive layer pós-LLM: garante que toda sessão cai num dia permitido
 * (availableDays). Sessões fora do conjunto são MOVIDAS pro dia permitido
 * mais próximo (distância cíclica em uma semana de 7 dias). Se o destino
 * já está ocupado, tenta o próximo permitido; se todos colidem, drop.
 *
 * Preserva o tipo da sessão (Easy, Long Run, etc) — só muda o `dayOfWeek`.
 *
 * Semana 1 respeita `startDayOfWeek`: não move sessão pra dia anterior
 * ao startDate da semana 1 (impossível treinar antes do plano começar).
 *
 * No-op quando `availableDays` é null/undefined/vazio.
 */

export interface EnforceDaysOp {
  scope: 'move' | 'drop';
  weekNumber: number;
  from: number;
  to?: number;
  reason?: string;
}

export interface EnforceDaysResult {
  weeks: PlanWeek[];
  ops: EnforceDaysOp[];
}

export function enforceAvailableDays(
  weeks: PlanWeek[],
  availableDays: number[] | null | undefined,
  startDayOfWeek: number | null = null,
): EnforceDaysResult {
  const ops: EnforceDaysOp[] = [];
  if (!availableDays || availableDays.length === 0) {
    return { weeks, ops };
  }
  const allowed = new Set(availableDays);
  const allowedSorted = [...availableDays].sort((a, b) => a - b);

  const out: PlanWeek[] = weeks.map((w, idx) => {
    const isFirstWeek = idx === 0;
    const occupied = new Set<number>();
    const newSessions: PlanWeek['sessions'] = [];

    for (const s of w.sessions) {
      if (allowed.has(s.dayOfWeek) && !occupied.has(s.dayOfWeek)) {
        // Já legal e dia livre — mantém.
        occupied.add(s.dayOfWeek);
        newSessions.push({ ...s });
        continue;
      }

      // Precisa mover. Encontra dia legal mais próximo cíclico, ainda livre,
      // e — se semana 1 — não anterior ao startDayOfWeek.
      const candidates = orderByCyclicProximity(s.dayOfWeek, allowedSorted)
        .filter((d) => !occupied.has(d))
        .filter((d) => !(isFirstWeek && startDayOfWeek != null && d < startDayOfWeek));

      if (candidates.length === 0) {
        ops.push({
          scope: 'drop',
          weekNumber: w.weekNumber,
          from: s.dayOfWeek,
          reason: 'no_free_allowed_day',
        });
        continue;
      }

      const target = candidates[0];
      ops.push({
        scope: 'move',
        weekNumber: w.weekNumber,
        from: s.dayOfWeek,
        to: target,
      });
      occupied.add(target);
      newSessions.push({ ...s, dayOfWeek: target });
    }

    // Mantém ordem por dayOfWeek pra render consistente.
    newSessions.sort((a, b) => a.dayOfWeek - b.dayOfWeek);
    return { ...w, sessions: newSessions };
  });

  return { weeks: out, ops };
}

/**
 * Ordena dias permitidos pela distância cíclica até `from` (semana de 7d).
 * Empate desempata pelo dia menor (favorece dia anterior).
 */
function orderByCyclicProximity(from: number, allowed: number[]): number[] {
  return [...allowed].sort((a, b) => {
    const da = cyclicDistance(from, a);
    const db = cyclicDistance(from, b);
    if (da !== db) return da - db;
    return a - b;
  });
}

function cyclicDistance(a: number, b: number): number {
  const diff = Math.abs(a - b);
  return Math.min(diff, 7 - diff);
}
