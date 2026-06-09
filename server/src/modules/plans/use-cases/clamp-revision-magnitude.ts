import { PlanWeek } from '../domain/plan.entity';
import { logger } from '@shared/logger/logger';

/**
 * Cap absoluto pós-LLM: garante que nenhuma semana revisada
 * tenha volume < 70% nem > 110% da semana anterior efetiva.
 *
 * Sem isso o LLM pode mandar deload de 83% (18km → 3km) e nada
 * normaliza — o prompt sugere "15-30%" mas o modelo ignora.
 *
 * Aplicado SOMENTE em weeks > currentWeekNumber (past intacto).
 * Race week + taper já são preservados por enforceRevisionInvariants
 * antes daqui; mas se vierem, deixamos passar (eles permanecem como base).
 *
 * Quando viola, ESCALA proporcionalmente as distâncias das sessões
 * pra atingir o piso/teto, mantendo a estrutura (sessões e tipos).
 *
 * Log `plan.revision.clamped` com delta original e clampado pra detectar
 * LLM aluado em produção.
 */
export const REVISION_VOLUME_FLOOR_PCT = 0.7; // deload max 30%
export const REVISION_VOLUME_CEILING_PCT = 1.1; // build max 10%

export function clampRevisionMagnitude(
  mergedWeeks: PlanWeek[],
  previousEffective: PlanWeek[],
  currentWeekNumber: number,
  context: { planId: string; userId: string },
): { weeks: PlanWeek[]; clamped: Array<{ weekNumber: number; before: number; after: number; reason: 'floor' | 'ceiling' }> } {
  const previousByNumber = new Map(previousEffective.map((w) => [w.weekNumber, w]));
  const clamped: Array<{ weekNumber: number; before: number; after: number; reason: 'floor' | 'ceiling' }> = [];

  const out = mergedWeeks.map((w) => {
    if (w.weekNumber <= currentWeekNumber) return w;
    const prev = previousByNumber.get(w.weekNumber);
    if (!prev) return w;
    const prevVol = totalVol(prev);
    if (prevVol <= 0) return w;
    const newVol = totalVol(w);
    const floor = prevVol * REVISION_VOLUME_FLOOR_PCT;
    const ceiling = prevVol * REVISION_VOLUME_CEILING_PCT;

    let factor = 1;
    let reason: 'floor' | 'ceiling' | null = null;
    if (newVol < floor) {
      factor = floor / newVol;
      reason = 'floor';
    } else if (newVol > ceiling) {
      factor = ceiling / newVol;
      reason = 'ceiling';
    }
    if (reason == null) return w;

    const scaled: PlanWeek = {
      ...w,
      sessions: w.sessions.map((s) => ({
        ...s,
        distanceKm: roundKm(s.distanceKm * factor),
      })),
    };
    const after = totalVol(scaled);
    clamped.push({ weekNumber: w.weekNumber, before: newVol, after, reason });
    return scaled;
  });

  if (clamped.length > 0) {
    logger.warn('plan.revision.clamped', {
      planId: context.planId,
      userId: context.userId,
      currentWeekNumber,
      clamps: clamped.map((c) =>
        `wk${c.weekNumber}: ${c.before.toFixed(1)}km → ${c.after.toFixed(1)}km (${c.reason})`,
      ),
    });
  }

  return { weeks: out, clamped };
}

function totalVol(w: PlanWeek): number {
  return w.sessions.reduce((s, x) => s + (x.distanceKm ?? 0), 0);
}

function roundKm(km: number): number {
  // 0.5km precision pra não ficar com 2.137km esquisito
  return Math.round(km * 2) / 2;
}
