import { Plan, PlanSession, PlanWeek } from '../domain/plan.entity';
import { RaceDistanceKm } from './plan-windows.constants';
import { logger } from '@shared/logger/logger';

/**
 * Configuração de taper por distância da prova. Reflete prática consolidada
 * de coaching pra cada distância: o quanto reduzir volume, quantos dias de
 * descanso antes da prova, quantas semanas a curva de taper cobre.
 *
 *  - 42K (maratona): taper de 2 semanas. Race week cai pra 45% do pico,
 *    taper week (N-1) pra 70%. 2 dias de descanso antes da prova.
 *  - 21K (meia): taper de 2 semanas com curva mais suave (55% race week,
 *    75% N-1). 2 dias de descanso.
 *  - 10K: taper de 1 semana (só race week a 65%). 2 dias de descanso.
 *  - 5K: taper de 1 semana (race week a 70%). 1 dia de descanso.
 */
export interface TaperConfig {
  taperWeeks: number;
  raceWeekVolPct: number;     // multiplicador do volume da semana pico
  taperWeekVolPct?: number;   // só se taperWeeks >= 2
  restDaysBeforeRace: number;
  maxSessionsRaceWeek: number;
}

export const TAPER_BY_DISTANCE: Record<RaceDistanceKm, TaperConfig> = {
  5:  { taperWeeks: 1, raceWeekVolPct: 0.70, restDaysBeforeRace: 1, maxSessionsRaceWeek: 4 },
  10: { taperWeeks: 1, raceWeekVolPct: 0.65, restDaysBeforeRace: 2, maxSessionsRaceWeek: 4 },
  21: { taperWeeks: 2, raceWeekVolPct: 0.55, taperWeekVolPct: 0.75, restDaysBeforeRace: 2, maxSessionsRaceWeek: 4 },
  42: { taperWeeks: 2, raceWeekVolPct: 0.45, taperWeekVolPct: 0.70, restDaysBeforeRace: 2, maxSessionsRaceWeek: 4 },
};

export function getTaperConfig(distanceKm: RaceDistanceKm): TaperConfig {
  return TAPER_BY_DISTANCE[distanceKm];
}

interface EnforceCtx {
  planId: string;
  raceDistanceKm: RaceDistanceKm;
  raceDayOfWeek: number;
}

interface EnforceResult {
  weeks: PlanWeek[];
  changes: string[];
}

/**
 * Sanitiza a race week e (se aplicável) a taper week imediatamente anterior.
 * Roda DEPOIS do markTargetSession. Garante invariantes que o LLM pode
 * violar mesmo sendo instruído:
 *
 *   1. Race week tem ≤ maxSessionsRaceWeek (override do frequency do user).
 *   2. Volume da race week ≤ raceWeekVolPct × pico do plano.
 *   3. Nos N dias antes da prova (raceDow - 1, -2, ...): rest OU recovery
 *      curtinho (≤4km, type=Easy). Sessões de tempo/interval são convertidas.
 *   4. Race week NÃO tem sessões com dayOfWeek > raceDow (já garantido pelo
 *      markTargetSession, mas reforçamos).
 *   5. (21K/42K) Taper week N-1 tem volume ≤ taperWeekVolPct × pico.
 *
 * Auto-repara o que conseguir; loga `plan.race_week.repaired` com diff de
 * changes pra captura de drift do LLM no Cloud Logging.
 */
export function enforceRaceWeekStructure(
  weeks: PlanWeek[],
  ctx: EnforceCtx,
): EnforceResult {
  if (weeks.length === 0) return { weeks, changes: [] };
  const config = getTaperConfig(ctx.raceDistanceKm);
  const changes: string[] = [];

  // ─── Calcular volume pico (excluindo race week e taper week) ──────────
  const raceWeekIdx = weeks.length - 1;
  const taperWeekIdx = raceWeekIdx - 1;
  const peakCandidateIdxs = weeks
    .map((_, i) => i)
    .filter(i => i !== raceWeekIdx && (config.taperWeeks < 2 || i !== taperWeekIdx));
  const peakVolume = peakCandidateIdxs.reduce((max, i) => {
    const vol = weekVolumeKm(weeks[i]);
    return vol > max ? vol : max;
  }, 0);

  // ─── Race week ────────────────────────────────────────────────────────
  let raceWeek = weeks[raceWeekIdx];
  const repairedRace = repairRaceWeek(raceWeek, ctx, config, peakVolume, changes);
  raceWeek = repairedRace;

  // ─── Taper week (só pra 21K/42K) ──────────────────────────────────────
  let taperWeek: PlanWeek | undefined;
  if (config.taperWeeks >= 2 && taperWeekIdx >= 0 && config.taperWeekVolPct) {
    taperWeek = weeks[taperWeekIdx];
    const taperCap = peakVolume * config.taperWeekVolPct;
    const taperVol = weekVolumeKm(taperWeek);
    if (taperVol > taperCap && peakVolume > 0) {
      taperWeek = scaleWeekVolume(taperWeek, taperCap / taperVol);
      changes.push(`taper_week(${taperWeek.weekNumber}): vol ${taperVol.toFixed(1)}km > cap ${taperCap.toFixed(1)}km → scaled to ${weekVolumeKm(taperWeek).toFixed(1)}km`);
    }
  }

  if (changes.length > 0) {
    logger.warn('plan.race_week.repaired', {
      planId: ctx.planId,
      raceDistanceKm: ctx.raceDistanceKm,
      raceDayOfWeek: ctx.raceDayOfWeek,
      peakVolumeKm: peakVolume,
      changes,
    });
  }

  const updated = weeks.map((w, i) => {
    if (i === raceWeekIdx) return raceWeek;
    if (taperWeek && i === taperWeekIdx) return taperWeek;
    return w;
  });
  return { weeks: updated, changes };
}

/**
 * Repara a estrutura da race week aplicando: cap de sessões, descanso pré-prova,
 * cap de volume. Mantém a sessão isTarget intacta — nunca toca ela.
 */
function repairRaceWeek(
  week: PlanWeek,
  ctx: EnforceCtx,
  config: TaperConfig,
  peakVolume: number,
  changes: string[],
): PlanWeek {
  let sessions = [...week.sessions];

  // Drop sessões pós-prova (defensivo — markTargetSession já fez isso, mas
  // se algo escapou, pega aqui).
  const beforeFilter = sessions.length;
  sessions = sessions.filter(s => s.dayOfWeek <= ctx.raceDayOfWeek);
  if (sessions.length < beforeFilter) {
    changes.push(`race_week(${week.weekNumber}): dropped ${beforeFilter - sessions.length} post-race sessions`);
  }

  // Garantir descanso nos N dias antes da prova. Converte sessões pesadas
  // (interval, tempo, long) em recovery ≤4km. Sessões já leves (easy ≤4km)
  // preserva. Permite manter a sessão isTarget intacta.
  const restWindowStart = ctx.raceDayOfWeek - config.restDaysBeforeRace;
  sessions = sessions.map(s => {
    if (s.isTarget) return s;
    if (s.dayOfWeek < restWindowStart || s.dayOfWeek >= ctx.raceDayOfWeek) return s;
    const isHeavy = isHeavySession(s);
    const isLong = s.distanceKm > 4;
    if (!isHeavy && !isLong) return s;
    changes.push(`race_week(${week.weekNumber}): converted heavy/long session day ${s.dayOfWeek} (${s.type}, ${s.distanceKm}km) → recovery easy 3km`);
    return {
      ...s,
      type: 'Easy',
      distanceKm: 3,
      durationMin: 20,
      notes: `[TAPER] Recovery curtinho — ${config.restDaysBeforeRace} dias antes da prova são pra preservar energia.`,
    };
  });

  // Cap de sessões na race week. Remove as MAIS PESADAS primeiro (preserva
  // sessão isTarget e as leves recentes).
  if (sessions.length > config.maxSessionsRaceWeek) {
    const removed: PlanSession[] = [];
    while (sessions.length > config.maxSessionsRaceWeek) {
      // Encontra a sessão mais distante da prova (menor dayOfWeek) que não é target
      // pra remover — preserva as sessões finais (sshakeout, target).
      const candidateIdx = sessions
        .map((s, i) => ({ s, i }))
        .filter(x => !x.s.isTarget)
        .sort((a, b) => a.s.dayOfWeek - b.s.dayOfWeek)[0]?.i;
      if (candidateIdx === undefined) break;
      removed.push(sessions[candidateIdx]);
      sessions = sessions.filter((_, i) => i !== candidateIdx);
    }
    if (removed.length > 0) {
      changes.push(`race_week(${week.weekNumber}): pruned ${removed.length} excess sessions (kept ≤${config.maxSessionsRaceWeek}), removed days ${removed.map(s => s.dayOfWeek).join(',')}`);
    }
  }

  // Cap de volume da race week. NÃO inclui a distância da sessão-prova nesse
  // cálculo (a prova é a prova — o cap é sobre o restante da semana).
  if (peakVolume > 0) {
    const volCap = peakVolume * config.raceWeekVolPct;
    const targetSession = sessions.find(s => s.isTarget);
    const restVol = sessions.filter(s => !s.isTarget).reduce((sum, s) => sum + s.distanceKm, 0);
    if (restVol > volCap) {
      const ratio = volCap / restVol;
      sessions = sessions.map(s => s.isTarget ? s : ({ ...s, distanceKm: Math.max(1, +(s.distanceKm * ratio).toFixed(1)) }));
      const newRest = sessions.filter(s => !s.isTarget).reduce((sum, s) => sum + s.distanceKm, 0);
      changes.push(`race_week(${week.weekNumber}): rest-vol ${restVol.toFixed(1)}km > cap ${volCap.toFixed(1)}km → scaled to ${newRest.toFixed(1)}km`);
    }
    // (mantém targetSession na conta de projectedLoadKm depois)
    void targetSession;
  }

  return { ...week, sessions: sessions.sort((a, b) => a.dayOfWeek - b.dayOfWeek) };
}

/** Soma de distanceKm de uma semana (todas as sessões, inclusive isTarget). */
function weekVolumeKm(week: PlanWeek): number {
  return week.sessions.reduce((sum, s) => sum + (s.distanceKm ?? 0), 0);
}

/** Reduz proporcionalmente o volume da semana para `ratio` × atual. */
function scaleWeekVolume(week: PlanWeek, ratio: number): PlanWeek {
  if (ratio >= 1) return week;
  return {
    ...week,
    sessions: week.sessions.map(s => ({
      ...s,
      distanceKm: Math.max(1, +(s.distanceKm * ratio).toFixed(1)),
    })),
  };
}

function isHeavySession(s: PlanSession): boolean {
  const t = (s.type ?? '').toLowerCase();
  return t.includes('interval') || t.includes('tempo') || t.includes('long') || t.includes('threshold');
}

// ──────────────────────────────────────────────────────────────────────────
// Revisão semanal: invariantes que o LLM precisa respeitar mesmo recebendo
// instrução no prompt. Se violar, repara e segue (não rejeita a revisão).
// ──────────────────────────────────────────────────────────────────────────

interface RevisionInvariantCtx {
  plan: Plan;
  /** Snapshot das semanas ANTES do merge — usado pra restaurar race week se LLM tocou. */
  originalWeeks: PlanWeek[];
  /** Semana atual (1-based). Revisão só pode mexer em weekNumber+1 e +2. */
  currentWeekNumber: number;
}

interface RevisionInvariantResult {
  weeks: PlanWeek[];
  changes: string[];
}

/**
 * Garante que a revisão semanal NÃO violou a âncora da prova:
 *
 *   1. weeks.length === plan.weeksCount (LLM não pode adicionar/remover semanas)
 *   2. Race week (última) mantém sessão isTarget no raceDayOfWeek correto
 *   3. Race week + taper week voltam ao snapshot original se foram tocadas
 *      (são INTOCÁVEIS na janela de revisão semanal — só geração inicial e
 *      checkpoints específicos podem mexer)
 *   4. Semanas <= currentWeekNumber também voltam ao snapshot (passado é frozen)
 *
 * Não rejeita a revisão — repara silenciosamente e loga `plan.revision.repaired`.
 */
export function enforceRevisionInvariants(
  mergedWeeks: PlanWeek[],
  ctx: RevisionInvariantCtx,
): RevisionInvariantResult {
  const changes: string[] = [];
  const { plan, originalWeeks, currentWeekNumber } = ctx;
  const isRace = !!plan.raceDayOfWeek;

  // 1. weeksCount preservado
  let weeks = mergedWeeks.slice();
  if (weeks.length !== plan.weeksCount) {
    // Reconstrói usando original como base + sobrepondo só o que faz sentido.
    changes.push(`weeksCount: merged ${weeks.length} !== plan ${plan.weeksCount} → restoring from snapshot`);
    weeks = originalWeeks.map(w => {
      const replacement = mergedWeeks.find(m => m.weekNumber === w.weekNumber);
      return replacement ?? w;
    });
  }

  // 2/3/4. Passado + race week + taper week voltam ao snapshot
  const raceWeekNumber = plan.weeksCount;
  const taperWeekNumber = raceWeekNumber - 1;
  weeks = weeks.map(w => {
    const isPast = w.weekNumber <= currentWeekNumber;
    const isRaceWeek = isRace && w.weekNumber === raceWeekNumber;
    const isTaperWeek = isRace && w.weekNumber === taperWeekNumber;
    if (!isPast && !isRaceWeek && !isTaperWeek) return w;

    const orig = originalWeeks.find(o => o.weekNumber === w.weekNumber);
    if (!orig) return w;
    // Compara minimamente: se sessions diferem por estrutura (count, dayOfWeek
    // do isTarget), restaura snapshot. Ignora isExecuted/executedRunId (esses
    // são atualizações de runs reais, não do LLM).
    if (sessionsStructurallyDifferent(w.sessions, orig.sessions)) {
      const label = isPast ? 'past' : isRaceWeek ? 'race_week' : 'taper_week';
      changes.push(`${label}(${w.weekNumber}): LLM modified protected week → restored from snapshot`);
      return orig;
    }
    return w;
  });

  // Sanity: a race week DEVE manter pelo menos uma sessão isTarget no raceDow.
  if (isRace) {
    const raceWeek = weeks.find(w => w.weekNumber === raceWeekNumber);
    if (raceWeek) {
      const hasTarget = raceWeek.sessions.some(s => s.isTarget && s.dayOfWeek === plan.raceDayOfWeek);
      if (!hasTarget) {
        const orig = originalWeeks.find(o => o.weekNumber === raceWeekNumber);
        if (orig) {
          weeks = weeks.map(w => w.weekNumber === raceWeekNumber ? orig : w);
          changes.push(`race_week(${raceWeekNumber}): isTarget missing after merge → restored from snapshot`);
        }
      }
    }
  }

  if (changes.length > 0) {
    logger.warn('plan.revision.repaired', {
      planId: plan.id,
      currentWeekNumber,
      raceWeekNumber,
      changes,
    });
  }

  return { weeks, changes };
}

function sessionsStructurallyDifferent(a: PlanSession[], b: PlanSession[]): boolean {
  if (a.length !== b.length) return true;
  const sortedA = [...a].sort((x, y) => x.dayOfWeek - y.dayOfWeek);
  const sortedB = [...b].sort((x, y) => x.dayOfWeek - y.dayOfWeek);
  for (let i = 0; i < sortedA.length; i++) {
    const sa = sortedA[i];
    const sb = sortedB[i];
    if (sa.dayOfWeek !== sb.dayOfWeek) return true;
    if (sa.type !== sb.type) return true;
    if (Math.abs((sa.distanceKm ?? 0) - (sb.distanceKm ?? 0)) > 0.1) return true;
    if (!!sa.isTarget !== !!sb.isTarget) return true;
  }
  return false;
}
