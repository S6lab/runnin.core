import { PlanSession, PlanWeek } from '../domain/plan.entity';

/**
 * Defensive layer pós-LLM: garante que o Long Run de cada semana cai num
 * dia coerente.
 *
 *  - Quando `longRunDayOfWeek` informado E presente em `availableDays`:
 *    move o Long Run pra esse dia (swap com a sessão que estiver lá).
 *  - Quando NÃO informado: garante que o Long Run cai em `availableDays`
 *    preferindo o último dia da semana disponível (sáb > sex > qui > …).
 *
 * Detecta Long Run por substring 'long' (case-insensitive) em `session.type`.
 * Se a semana não tem Long Run, no-op pra essa semana.
 *
 * Preserva sessões existentes via swap quando preciso (não dropa).
 *
 * No-op quando `availableDays` vazio (sem referência).
 */

export interface EnforceLongRunOp {
  scope: 'move_long_run' | 'swap_long_run';
  weekNumber: number;
  from: number;
  to: number;
}

export interface EnforceLongRunResult {
  weeks: PlanWeek[];
  ops: EnforceLongRunOp[];
}

function isLongRun(session: PlanSession): boolean {
  return session.type.toLowerCase().includes('long');
}

export function enforceLongRunDay(
  weeks: PlanWeek[],
  longRunDayOfWeek: number | null | undefined,
  availableDays: number[] | null | undefined,
): EnforceLongRunResult {
  const ops: EnforceLongRunOp[] = [];
  if (!availableDays || availableDays.length === 0) {
    return { weeks, ops };
  }
  const allowed = new Set(availableDays);
  const preferred = longRunDayOfWeek && allowed.has(longRunDayOfWeek)
    ? longRunDayOfWeek
    : null;

  const out: PlanWeek[] = weeks.map((w) => {
    const lrIdx = w.sessions.findIndex(isLongRun);
    if (lrIdx < 0) return w;
    const lr = w.sessions[lrIdx];

    // Alvo: dia preferido se informado/válido; senão último allowed
    // (típico fim de semana). Ambos garantidos em availableDays.
    const target = preferred ?? Math.max(...availableDays);

    if (lr.dayOfWeek === target) return w;

    // Procura sessão no dia alvo pra fazer swap (se houver).
    const occupantIdx = w.sessions.findIndex(
      (s, i) => i !== lrIdx && s.dayOfWeek === target,
    );

    const newSessions = w.sessions.map((s) => ({ ...s }));
    const fromDay = lr.dayOfWeek;
    newSessions[lrIdx] = { ...newSessions[lrIdx], dayOfWeek: target };
    if (occupantIdx >= 0) {
      newSessions[occupantIdx] = {
        ...newSessions[occupantIdx],
        dayOfWeek: fromDay,
      };
      ops.push({ scope: 'swap_long_run', weekNumber: w.weekNumber, from: fromDay, to: target });
    } else {
      ops.push({ scope: 'move_long_run', weekNumber: w.weekNumber, from: fromDay, to: target });
    }

    newSessions.sort((a, b) => a.dayOfWeek - b.dayOfWeek);
    return { ...w, sessions: newSessions };
  });

  return { weeks: out, ops };
}
