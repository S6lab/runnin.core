import { describe, it, expect } from 'vitest';
import { markTargetSession } from '@modules/plans/use-cases/sanitize-session-distance';
import {
  enforceRaceWeekStructure,
  enforceRevisionInvariants,
  getTaperConfig,
} from '@modules/plans/use-cases/enforce-race-week-structure';
import {
  deriveWeeksCountFromRaceDate,
  isoDateToDayOfWeek,
} from '@modules/plans/use-cases/race-date.helpers';
import type { Plan, PlanSession, PlanWeek } from '@modules/plans/domain/plan.entity';

// Helper pra montar PlanSession sem repetir defaults em cada test.
function sess(partial: Partial<PlanSession> & { dayOfWeek: number; distanceKm: number }): PlanSession {
  return {
    id: `s${partial.dayOfWeek}`,
    type: 'Easy',
    notes: '',
    ...partial,
  };
}

function week(weekNumber: number, sessions: PlanSession[]): PlanWeek {
  return {
    weekNumber,
    sessions: [...sessions].sort((a, b) => a.dayOfWeek - b.dayOfWeek),
    projectedLoadKm: sessions.reduce((s, x) => s + x.distanceKm, 0),
  };
}

// ───────────────────────────────────────────────────────────────────────────
// markTargetSession: alinhamento com raceDayOfWeek
// ───────────────────────────────────────────────────────────────────────────

describe('markTargetSession', () => {
  it('insere a prova no dayOfWeek do raceDate quando a última semana não tem sessão nesse dia', () => {
    // Última semana com sessões Mon (1), Wed (3), Fri (5). Prova num domingo (7).
    const weeks: PlanWeek[] = [
      week(1, [sess({ dayOfWeek: 1, type: 'Easy', distanceKm: 5 })]),
      week(2, [
        sess({ dayOfWeek: 1, type: 'Easy', distanceKm: 6 }),
        sess({ dayOfWeek: 3, type: 'Tempo', distanceKm: 8 }),
        sess({ dayOfWeek: 5, type: 'Long', distanceKm: 12 }),
      ]),
    ];
    const result = markTargetSession(weeks, 42, { raceDayOfWeek: 7 });
    const last = result[result.length - 1];
    const target = last.sessions.find(s => s.isTarget);
    expect(target).toBeDefined();
    expect(target!.dayOfWeek).toBe(7);
    expect(target!.distanceKm).toBe(42);
    expect(target!.type).toBe('Maratona');
    // Sessões originais permanecem
    expect(last.sessions.find(s => s.dayOfWeek === 1)?.type).toBe('Easy');
    expect(last.sessions.find(s => s.dayOfWeek === 3)?.type).toBe('Tempo');
    expect(last.sessions.find(s => s.dayOfWeek === 5)?.type).toBe('Long');
  });

  it('substitui a sessão existente no raceDayOfWeek se já houver uma', () => {
    const weeks: PlanWeek[] = [
      week(1, [
        sess({ dayOfWeek: 2, type: 'Easy', distanceKm: 6 }),
        sess({ dayOfWeek: 2, type: 'Tempo Run', distanceKm: 8 }),
      ]),
    ];
    // Prova numa terça (2). A primeira sessão de terça (Easy 6km) já existe.
    const result = markTargetSession(weeks, 21, { raceDayOfWeek: 2 });
    const last = result[result.length - 1];
    const targets = last.sessions.filter(s => s.isTarget);
    expect(targets).toHaveLength(1);
    expect(targets[0].dayOfWeek).toBe(2);
    expect(targets[0].distanceKm).toBe(21);
    expect(targets[0].type).toBe('Meia Maratona');
  });

  it('remove sessões com dayOfWeek > raceDayOfWeek (sem treino pós-prova)', () => {
    const weeks: PlanWeek[] = [
      week(1, [
        sess({ dayOfWeek: 2, type: 'Easy', distanceKm: 5 }),
        sess({ dayOfWeek: 4, type: 'Easy', distanceKm: 4 }),
        sess({ dayOfWeek: 6, type: 'Long', distanceKm: 14 }),
        sess({ dayOfWeek: 7, type: 'Easy', distanceKm: 5 }),
      ]),
    ];
    // Prova na quinta (4). Sessões de sábado (6) e domingo (7) devem cair.
    const result = markTargetSession(weeks, 10, { raceDayOfWeek: 4 });
    const last = result[result.length - 1];
    const days = last.sessions.map(s => s.dayOfWeek).sort();
    expect(days).toEqual([2, 4]); // só seg + qui (race)
    expect(last.sessions.find(s => s.dayOfWeek === 4)?.isTarget).toBe(true);
  });

  it('fallback legacy: sem raceDayOfWeek, substitui a última sessão da array', () => {
    const weeks: PlanWeek[] = [
      week(1, [
        sess({ dayOfWeek: 1, type: 'Easy', distanceKm: 5 }),
        sess({ dayOfWeek: 5, type: 'Long', distanceKm: 12 }),
      ]),
    ];
    const result = markTargetSession(weeks, 21);
    const last = result[result.length - 1];
    const target = last.sessions.find(s => s.isTarget);
    expect(target).toBeDefined();
    // No legacy, é a última do array (dayOfWeek 5, era a Long)
    expect(target!.dayOfWeek).toBe(5);
    expect(target!.distanceKm).toBe(21);
  });
});

// ───────────────────────────────────────────────────────────────────────────
// enforce-race-week-structure: taper + cap de sessões + rest pré-prova
// ───────────────────────────────────────────────────────────────────────────

describe('enforceRaceWeekStructure', () => {
  it('poda a race week pra ≤4 sessões mesmo quando user treina 7d/semana', () => {
    const peak = week(1, Array.from({ length: 6 }, (_, i) =>
      sess({ id: `p${i}`, dayOfWeek: i + 1, type: 'Easy', distanceKm: 10 }),
    ));
    // Race week com 7 sessões (frequência 7)
    const raceWeek = week(2, [
      sess({ dayOfWeek: 1, type: 'Easy', distanceKm: 5 }),
      sess({ dayOfWeek: 2, type: 'Easy', distanceKm: 5 }),
      sess({ dayOfWeek: 3, type: 'Tempo', distanceKm: 6 }),
      sess({ dayOfWeek: 4, type: 'Easy', distanceKm: 4 }),
      sess({ dayOfWeek: 5, type: 'Easy', distanceKm: 4 }),
      sess({ dayOfWeek: 6, type: 'Easy', distanceKm: 3 }),
      sess({ id: 'race', dayOfWeek: 7, type: 'Maratona', distanceKm: 42, isTarget: true }),
    ]);
    const result = enforceRaceWeekStructure([peak, raceWeek], {
      planId: 'p1',
      raceDistanceKm: 42,
      raceDayOfWeek: 7,
    });
    const finalRace = result.weeks[result.weeks.length - 1];
    expect(finalRace.sessions.length).toBeLessThanOrEqual(4);
    // Sessão isTarget tem que estar preservada
    expect(finalRace.sessions.find(s => s.isTarget)?.dayOfWeek).toBe(7);
    expect(result.changes.length).toBeGreaterThan(0);
  });

  it('converte sessões pesadas em D-1 e D-2 pra recovery ≤4km', () => {
    const peak = week(1, [
      sess({ dayOfWeek: 1, distanceKm: 10 }),
      sess({ dayOfWeek: 3, distanceKm: 10 }),
      sess({ dayOfWeek: 5, distanceKm: 10 }),
    ]);
    const raceWeek = week(2, [
      sess({ id: 'd5', dayOfWeek: 5, type: 'Tempo Run', distanceKm: 8 }),
      sess({ id: 'd6', dayOfWeek: 6, type: 'Interval', distanceKm: 6 }),
      sess({ id: 'race', dayOfWeek: 7, type: 'Maratona', distanceKm: 42, isTarget: true }),
    ]);
    const result = enforceRaceWeekStructure([peak, raceWeek], {
      planId: 'p1',
      raceDistanceKm: 42,
      raceDayOfWeek: 7,
    });
    const final = result.weeks[result.weeks.length - 1];
    const d5 = final.sessions.find(s => s.dayOfWeek === 5);
    const d6 = final.sessions.find(s => s.dayOfWeek === 6);
    expect(d5?.type).toBe('Easy');
    expect(d5?.distanceKm).toBeLessThanOrEqual(4);
    expect(d6?.type).toBe('Easy');
    expect(d6?.distanceKm).toBeLessThanOrEqual(4);
    // Target intacto
    expect(final.sessions.find(s => s.isTarget)?.distanceKm).toBe(42);
  });

  it('aplica cap de volume na race week (≤45% do pico pra 42K)', () => {
    // Pra 42K (taperWeeks=2), o enforcer exclui as 2 últimas semanas do
    // cálculo de pico. Precisamos de ≥3 semanas: pico + taper + race.
    const peakWeek = week(1, [
      sess({ id: 'p1', dayOfWeek: 1, distanceKm: 12 }),
      sess({ id: 'p3', dayOfWeek: 3, distanceKm: 12 }),
      sess({ id: 'p5', dayOfWeek: 5, distanceKm: 36 }), // pico 60km
    ]);
    const taperWeek = week(2, [
      sess({ id: 't1', dayOfWeek: 1, distanceKm: 8 }),
      sess({ id: 't5', dayOfWeek: 5, distanceKm: 20 }),
    ]);
    const raceWeek = week(3, [
      sess({ id: 'rw1', dayOfWeek: 1, type: 'Easy', distanceKm: 15 }),
      sess({ id: 'rw3', dayOfWeek: 3, type: 'Easy', distanceKm: 15 }),
      sess({ id: 'race', dayOfWeek: 7, type: 'Maratona', distanceKm: 42, isTarget: true }),
    ]);
    const result = enforceRaceWeekStructure([peakWeek, taperWeek, raceWeek], {
      planId: 'p1',
      raceDistanceKm: 42,
      raceDayOfWeek: 7,
    });
    const final = result.weeks[result.weeks.length - 1];
    const restVol = final.sessions.filter(s => !s.isTarget).reduce((sum, s) => sum + s.distanceKm, 0);
    // 45% × 60km = 27km de cap (exclui a target)
    expect(restVol).toBeLessThanOrEqual(27 + 0.5); // tolerância arredondamento
  });
});

// ───────────────────────────────────────────────────────────────────────────
// deriveWeeksCountFromRaceDate
// ───────────────────────────────────────────────────────────────────────────

describe('deriveWeeksCountFromRaceDate', () => {
  it('70 dias até a prova → 10 semanas', () => {
    const result = deriveWeeksCountFromRaceDate(
      { goalKind: 'race', raceDate: '2026-08-04' },
      '2026-05-26',
    );
    expect(result).toBe(10); // 70 / 7 = 10 exato
  });

  it('arredonda para cima quando não dá semanas exatas', () => {
    const result = deriveWeeksCountFromRaceDate(
      { goalKind: 'race', raceDate: '2026-06-15' }, // 20 dias
      '2026-05-26',
    );
    expect(result).toBe(3); // ceil(20/7) = 3
  });

  it('retorna undefined sem raceDate', () => {
    const result = deriveWeeksCountFromRaceDate({ goalKind: 'race' }, '2026-05-26');
    expect(result).toBeUndefined();
  });

  it('retorna undefined quando raceDate é no passado', () => {
    const result = deriveWeeksCountFromRaceDate(
      { goalKind: 'race', raceDate: '2026-01-01' },
      '2026-05-26',
    );
    expect(result).toBeUndefined();
  });
});

describe('isoDateToDayOfWeek', () => {
  it('mapeia segunda-feira → 1', () => {
    expect(isoDateToDayOfWeek('2026-05-25')).toBe(1); // Mon
  });
  it('mapeia domingo → 7', () => {
    expect(isoDateToDayOfWeek('2026-05-31')).toBe(7); // Sun
  });
});

describe('getTaperConfig', () => {
  it('maratona: 2 semanas de taper, 2 dias de descanso', () => {
    const c = getTaperConfig(42);
    expect(c.taperWeeks).toBe(2);
    expect(c.restDaysBeforeRace).toBe(2);
  });
  it('5K: 1 semana de taper, 1 dia de descanso', () => {
    const c = getTaperConfig(5);
    expect(c.taperWeeks).toBe(1);
    expect(c.restDaysBeforeRace).toBe(1);
  });
});

// ───────────────────────────────────────────────────────────────────────────
// enforceRevisionInvariants: âncora da prova durante revisão semanal
// ───────────────────────────────────────────────────────────────────────────

describe('enforceRevisionInvariants', () => {
  function makePlan(weeks: PlanWeek[]): Plan {
    return {
      id: 'p1',
      userId: 'u1',
      goal: 'Maratona',
      level: 'intermediario',
      weeksCount: weeks.length,
      status: 'ready',
      weeks,
      raceDate: '2026-09-13',
      raceDayOfWeek: 7,
      createdAt: '2026-04-01T00:00:00Z',
      updatedAt: '2026-04-01T00:00:00Z',
    };
  }

  it('restaura race week quando o LLM mexer nela', () => {
    const original = makePlan([
      week(1, [sess({ dayOfWeek: 1, distanceKm: 5 })]),
      week(2, [sess({ dayOfWeek: 1, distanceKm: 6 })]),
      week(3, [
        sess({ dayOfWeek: 1, distanceKm: 3 }),
        sess({ id: 'race', dayOfWeek: 7, type: 'Maratona', distanceKm: 42, isTarget: true }),
      ]),
    ]);
    // LLM violou: race week (3) virou Easy 10km, target removido.
    const merged: PlanWeek[] = [
      original.weeks[0],
      original.weeks[1],
      week(3, [sess({ dayOfWeek: 1, type: 'Easy', distanceKm: 10 })]),
    ];
    const result = enforceRevisionInvariants(merged, {
      plan: original,
      originalWeeks: original.weeks,
      currentWeekNumber: 1,
    });
    const raceWeek = result.weeks.find(w => w.weekNumber === 3);
    expect(raceWeek?.sessions.find(s => s.isTarget)?.distanceKm).toBe(42);
    expect(result.changes.length).toBeGreaterThan(0);
  });

  it('repõe semanas removidas pelo LLM (weeksCount preservado)', () => {
    const original = makePlan([
      week(1, [sess({ dayOfWeek: 1, distanceKm: 5 })]),
      week(2, [sess({ dayOfWeek: 1, distanceKm: 6 })]),
      week(3, [
        sess({ id: 'race', dayOfWeek: 7, type: 'Maratona', distanceKm: 42, isTarget: true }),
      ]),
    ]);
    // LLM devolveu só 2 semanas em vez de 3.
    const merged = [original.weeks[0], original.weeks[1]];
    const result = enforceRevisionInvariants(merged, {
      plan: original,
      originalWeeks: original.weeks,
      currentWeekNumber: 1,
    });
    expect(result.weeks).toHaveLength(3);
    expect(result.weeks[2].sessions.find(s => s.isTarget)?.distanceKm).toBe(42);
    expect(result.changes.some(c => c.includes('weeksCount'))).toBe(true);
  });

  it('aceita mudanças do LLM na janela revisável quando race week e taper week não foram tocadas', () => {
    // Plano de 5 semanas: 1-3 = treino, 4 = taper, 5 = race.
    // currentWeekNumber = 1 → janela revisável = semanas 2 e 3.
    const original = makePlan([
      week(1, [sess({ dayOfWeek: 1, distanceKm: 5 })]),
      week(2, [sess({ dayOfWeek: 1, distanceKm: 6 })]),
      week(3, [sess({ dayOfWeek: 1, distanceKm: 7 })]),
      week(4, [sess({ dayOfWeek: 1, distanceKm: 4 })]), // taper
      week(5, [
        sess({ id: 'race', dayOfWeek: 7, type: 'Maratona', distanceKm: 42, isTarget: true }),
      ]),
    ]);
    // LLM ajustou semanas 2 e 3 (janela revisável). Não tocou em race/taper.
    const merged: PlanWeek[] = [
      original.weeks[0], // passado intocado
      week(2, [sess({ dayOfWeek: 1, distanceKm: 7.5 })]), // ajustado
      week(3, [sess({ dayOfWeek: 1, distanceKm: 8.5 })]), // ajustado
      original.weeks[3], // taper intocado
      original.weeks[4], // race intocada
    ];
    const result = enforceRevisionInvariants(merged, {
      plan: original,
      originalWeeks: original.weeks,
      currentWeekNumber: 1,
    });
    expect(result.changes).toHaveLength(0);
    expect(result.weeks[1].sessions[0].distanceKm).toBe(7.5);
    expect(result.weeks[2].sessions[0].distanceKm).toBe(8.5);
  });
});
