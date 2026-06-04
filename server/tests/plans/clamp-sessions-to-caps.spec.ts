import { describe, it, expect } from 'vitest';
import { clampSessionsToCaps } from '@modules/plans/use-cases/clamp-sessions-to-caps';
import type { PlanSession, PlanWeek } from '@modules/plans/domain/plan.entity';

function sess(partial: Partial<PlanSession> & { dayOfWeek: number; distanceKm: number }): PlanSession {
  return {
    id: `s${partial.dayOfWeek}-${partial.distanceKm}`,
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

describe('clampSessionsToCaps — sessão-meta preservada', () => {
  it('quando a semana excede o cap mas tem uma sessão-meta isTarget, escala SÓ as outras sessões', () => {
    // Cenário do bug: iniciante reportou currentWeeklyKm=2; plano de 10K
    // com a última semana sendo a race week (3 sessões + meta 10K).
    // Antes do fix: a 10K virava 3.5km porque a semana inteira escalava.
    const weeks: PlanWeek[] = [
      week(14, [
        sess({ dayOfWeek: 2, distanceKm: 3 }),
        sess({ dayOfWeek: 4, distanceKm: 3 }),
        sess({ dayOfWeek: 6, distanceKm: 2, type: 'Recovery' }),
        sess({ dayOfWeek: 7, distanceKm: 10, type: '10K', isTarget: true }),
      ]),
    ];

    // currentWeeklyKm=2 → base flooreada em 5 → cap S14 = 5×(1.1+0.1×13) = 12km.
    // Total = 18km → exceeds. Sem o fix, ratio = 12/18 = 0.67 → 10K vira 6.7km.
    // Com o fix: target preservada (10km), resto (8km) cai pra cap_scalable
    // = 12-10 = 2km, ratio = 2/8 = 0.25 → as outras viram ~0.75, ~0.75, ~0.5.
    const result = clampSessionsToCaps(weeks, {
      currentWeeklyKm: 2,
      capacityDistanceKm: 3,
      requiredPeakKm: 18,
    });

    const targetSession = result.weeks[0].sessions.find(s => s.isTarget);
    expect(targetSession?.distanceKm).toBe(10);
    // Confirma que outras sessões foram escaladas
    const nonTarget = result.weeks[0].sessions.filter(s => !s.isTarget);
    const nonTargetTotal = nonTarget.reduce((s, x) => s + x.distanceKm, 0);
    expect(nonTargetTotal).toBeLessThanOrEqual(2); // cap_scalable
    // E que houve um op de clamp pra logging
    expect(result.ops.some(o => o.scope === 'weekly_volume')).toBe(true);
  });

  it('iniciante com currentWeeklyKm=0/null usa o floor de 5km — cap S14 ≈ 12km, não absurdo baixo', () => {
    // Antes do fix: floor não era aplicado → cap = 0 × ramp = 0 → tudo zerado.
    const weeks: PlanWeek[] = [
      week(14, [
        sess({ dayOfWeek: 6, distanceKm: 3 }),
        sess({ dayOfWeek: 7, distanceKm: 10, type: '10K', isTarget: true }),
      ]),
    ];
    const result = clampSessionsToCaps(weeks, {
      currentWeeklyKm: null,
      capacityDistanceKm: null,
      requiredPeakKm: 18,
    });
    // Total 13km vs cap 12 — só clampa um pouco a sessão não-target.
    const target = result.weeks[0].sessions.find(s => s.isTarget);
    expect(target?.distanceKm).toBe(10);
    const nonTarget = result.weeks[0].sessions.find(s => !s.isTarget)!;
    // 3km cabe em cap_scalable = 12 - 10 = 2 → escalou pra ~2
    expect(nonTarget.distanceKm).toBeLessThanOrEqual(3);
  });

  it('semana sem isTarget escala proporcionalmente como antes', () => {
    const weeks: PlanWeek[] = [
      week(1, [
        sess({ dayOfWeek: 2, distanceKm: 5 }),
        sess({ dayOfWeek: 4, distanceKm: 5 }),
        sess({ dayOfWeek: 6, distanceKm: 5 }),
      ]),
    ];
    // S1: base 5, cap = 5 × 1.1 = 5.5km. Total = 15km → ratio = 5.5/15 ≈ 0.37
    const result = clampSessionsToCaps(weeks, {
      currentWeeklyKm: 2,
      capacityDistanceKm: null,
    });
    const total = result.weeks[0].sessions.reduce((s, x) => s + x.distanceKm, 0);
    expect(total).toBeLessThanOrEqual(5.5 + 0.5);
    expect(result.ops[0].scope).toBe('weekly_volume');
  });

  it('quando NÃO há scaling necessário (total ≤ cap), nada é mudado', () => {
    // weeklyCap usa o índice 0-based do array passado, então pra simular
    // S14 a função precisa receber as 14 semanas (mesmo que sejam dummies).
    const weeks: PlanWeek[] = [];
    for (let i = 1; i <= 13; i++) {
      weeks.push(week(i, [sess({ dayOfWeek: 7, distanceKm: 1 })]));
    }
    weeks.push(
      week(14, [
        sess({ dayOfWeek: 6, distanceKm: 2 }),
        sess({ dayOfWeek: 7, distanceKm: 10, type: '10K', isTarget: true }),
      ]),
    );
    const result = clampSessionsToCaps(weeks, {
      currentWeeklyKm: 5,
      requiredPeakKm: 18,
    });
    // base 5, cap S14 (i=13) = min(5 × (1.1 + 0.1×13), 18) = min(12, 18) = 12.
    // S14 total = 12 ≤ 12 → no clamp em S14. Semanas anteriores podem clampar
    // mas a meta deve permanecer intacta na S14.
    const lastWeek = result.weeks[result.weeks.length - 1];
    expect(lastWeek.sessions.find(s => s.isTarget)?.distanceKm).toBe(10);
    // Sem ops na S14 especificamente.
    expect(result.ops.find(o => o.weekNumber === 14)).toBeUndefined();
  });

  it('requiredPeakKm trava o cap quando a rampa o ultrapassaria', () => {
    // currentWeeklyKm=20, S14 sem peak: cap = 20 × 2.4 = 48km.
    // Com peak=18, trava em 18.
    const weeks: PlanWeek[] = [week(14, [sess({ dayOfWeek: 1, distanceKm: 30 })])];
    const result = clampSessionsToCaps(weeks, {
      currentWeeklyKm: 20,
      requiredPeakKm: 18,
    });
    expect(result.weeks[0].sessions[0].distanceKm).toBeLessThanOrEqual(18 + 0.1);
  });
});
