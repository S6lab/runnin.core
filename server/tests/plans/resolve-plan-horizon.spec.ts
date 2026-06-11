import { describe, it, expect, afterEach } from 'vitest';
import {
  resolvePlanHorizon,
  civilDateAtOffset,
  PlanHorizonError,
  MAX_PLAN_WEEKS,
} from '@modules/plans/use-cases/resolve-plan-horizon';

afterEach(() => {
  delete process.env['HORIZON_STRICT'];
});

describe('civilDateAtOffset', () => {
  it('22h BRT (UTC-3) ainda é HOJE na data civil do atleta', () => {
    // 2026-06-12T01:00Z = 2026-06-11 22:00 em BRT.
    const now = new Date('2026-06-12T01:00:00Z');
    expect(civilDateAtOffset(now, -180)).toBe('2026-06-11');
  });

  it('sem tzOffsetMin cai na data UTC (legado)', () => {
    const now = new Date('2026-06-12T01:00:00Z');
    expect(civilDateAtOffset(now, null)).toBe('2026-06-12');
  });
});

describe('resolvePlanHorizon — startDate', () => {
  it('startDate explícito vence qualquer offset', () => {
    const h = resolvePlanHorizon(
      { startDate: '2026-06-11', tzOffsetMin: -180 },
      { fallbackWeeks: 8 },
    );
    expect(h.startDate).toBe('2026-06-11');
    expect(h.startDayOfWeek).toBe(4); // quinta
  });

  it('startDate ausente + tzOffsetMin resolve "hoje" na data civil do atleta', () => {
    const h = resolvePlanHorizon(
      { tzOffsetMin: -180 },
      { fallbackWeeks: 8, now: new Date('2026-06-12T01:00:00Z') },
    );
    expect(h.startDate).toBe('2026-06-11');
  });

  it('startDate que passa no regex mas não existe (2026-02-31) → 422', () => {
    expect(() =>
      resolvePlanHorizon({ startDate: '2026-02-31' }, { fallbackWeeks: 8 }),
    ).toThrow(PlanHorizonError);
  });
});

describe('resolvePlanHorizon — raceDate soberana', () => {
  it('weeks derivado da raceDate VENCE input.weeksCount em mismatch', () => {
    // 2026-06-11 (qui) → 2026-09-13 (dom) = 94 dias = ceil 14 semanas.
    const h = resolvePlanHorizon(
      {
        goalKind: 'race',
        startDate: '2026-06-11',
        raceDate: '2026-09-13',
        weeksCount: 10, // cliente stale
      },
      { fallbackWeeks: 8 },
    );
    expect(h.weeksCount).toBe(14);
    expect(h.raceDate).toBe('2026-09-13');
    expect(h.raceDayOfWeek).toBe(7); // domingo
    expect(h.initialDeadlineAt).toBe('2026-09-13');
  });

  it('raceDate <= startDate em modo warn: cai no fallback e perde a âncora', () => {
    const h = resolvePlanHorizon(
      {
        goalKind: 'race',
        startDate: '2026-06-11',
        raceDate: '2026-06-11',
      },
      { fallbackWeeks: 8 },
    );
    expect(h.weeksCount).toBe(8);
    expect(h.raceDayOfWeek).toBeUndefined();
  });

  it('raceDate <= startDate em modo enforce: 422', () => {
    process.env['HORIZON_STRICT'] = 'enforce';
    expect(() =>
      resolvePlanHorizon(
        { goalKind: 'race', startDate: '2026-06-11', raceDate: '2026-06-10' },
        { fallbackWeeks: 8 },
      ),
    ).toThrow(PlanHorizonError);
  });

  it('raceDate além de 365 dias em modo enforce: 422', () => {
    process.env['HORIZON_STRICT'] = 'enforce';
    expect(() =>
      resolvePlanHorizon(
        { goalKind: 'race', startDate: '2026-06-11', raceDate: '2027-07-01' },
        { fallbackWeeks: 8 },
      ),
    ).toThrow(PlanHorizonError);
  });

  it(`derived acima de ${MAX_PLAN_WEEKS} semanas em modo warn passa (telemetria), em enforce: 422`, () => {
    const input = {
      goalKind: 'race' as const,
      startDate: '2026-06-11',
      raceDate: '2027-03-01', // ~38 semanas
    };
    const warn = resolvePlanHorizon(input, { fallbackWeeks: 8 });
    expect(warn.weeksCount).toBeGreaterThan(MAX_PLAN_WEEKS);

    process.env['HORIZON_STRICT'] = 'enforce';
    expect(() => resolvePlanHorizon(input, { fallbackWeeks: 8 })).toThrow(PlanHorizonError);
  });

  it('raceDate inválida (2026-02-31) → 422 mesmo em warn', () => {
    expect(() =>
      resolvePlanHorizon(
        { goalKind: 'race', startDate: '2026-06-11', raceDate: '2026-02-31' },
        { fallbackWeeks: 8 },
      ),
    ).toThrow(PlanHorizonError);
  });

  it('flow ignora raceDate e usa input/fallback', () => {
    const h = resolvePlanHorizon(
      { goalKind: 'flow', startDate: '2026-06-11', raceDate: '2026-09-13', weeksCount: 10 },
      { fallbackWeeks: 8 },
    );
    expect(h.weeksCount).toBe(10);
    expect(h.raceDate).toBeUndefined();
    expect(h.initialDeadlineAt).toBe('2026-08-19'); // start + 70 - 1 dias
  });
});
