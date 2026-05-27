import { RunnerLevel } from '@modules/users/domain/user.entity';
import { PlanWeek } from '../domain/plan.entity';
import { logger } from '@shared/logger/logger';
import { MAX_KM_PER_SESSION, RaceDistanceKm } from './plan-windows.constants';

/** Cap de ratio long-run/total-da-semana. Above isso = base aeróbica
 *  inexistente (W15 do edu tinha 78%). Mantém em 50% por padrão (decidido
 *  com user). */
export const MAX_LONG_RUN_RATIO = 0.50;

/**
 * Clampa distanceKm em MAX_KM_PER_SESSION pro nível. LLM ocasionalmente
 * cospe session.distanceKm acima do cap (iniciante 18km em "Long Run"),
 * o que vira plano perigoso. Mesmo com prompt instruindo, essa rede de
 * proteção runtime garante.
 */
export function clampSessionDistance(
  distanceKm: number,
  level: RunnerLevel,
  ctx: { weekNumber?: number; dayOfWeek?: number; sessionType?: string } = {},
): number {
  const cap = MAX_KM_PER_SESSION[level];
  if (distanceKm <= cap) return distanceKm;
  logger.warn('plan.session.distance.clamped', {
    rawDistanceKm: distanceKm,
    cap,
    level,
    ...ctx,
  });
  return cap;
}

interface SessionLike {
  distanceKm: number;
  type?: string;
  dayOfWeek?: number;
}

/**
 * Garante que o long run (sessão de maior distância da semana) não
 * domina mais de MAX_LONG_RUN_RATIO do volume semanal. Caso passe, REDUZ
 * a distância do long run pra exatamente MAX × total_outras.
 *
 * Por que reduzir o long run em vez de aumentar as outras: aumentar
 * outras sessões mexeria em hidratação/nutrição/notes do LLM e seria
 * inconsistente. Reduzir é cirúrgico.
 *
 * Ex: total=23km, long=18km (78%) → cap em 50% × (23 - 18) / (1 - 0.50) =
 *   long_new = 5 × 0.50 / 0.50 = 5km? Não, vamos resolver direito:
 *   queremos new_long / (new_long + outros) <= 0.50
 *   → new_long <= 0.50 × (new_long + outros)
 *   → new_long × 0.50 <= 0.50 × outros
 *   → new_long <= outros (com 50%, long == soma das outras)
 *   Então new_long = sum(outras)
 *
 * Resultado pro caso W15: outros = 5km → new_long = 5km. Plano fica
 * 5 + 5 = 10km totais (era 23km). É um cap brutal mas explicita o
 * problema do LLM: aquela semana NÃO tinha sessão suficiente.
 */
export function enforceWeeklyLongRunRatio<T extends SessionLike>(
  sessions: T[],
  ctx: { weekNumber?: number; level?: RunnerLevel } = {},
): T[] {
  if (sessions.length === 0) return sessions;
  if (sessions.length === 1) return sessions; // semana de 1 sessão, sem ratio possível
  const total = sessions.reduce((s, x) => s + x.distanceKm, 0);
  if (total <= 0) return sessions;
  let maxIdx = 0;
  for (let i = 1; i < sessions.length; i++) {
    if (sessions[i].distanceKm > sessions[maxIdx].distanceKm) maxIdx = i;
  }
  const long = sessions[maxIdx];
  const ratio = long.distanceKm / total;
  if (ratio <= MAX_LONG_RUN_RATIO) return sessions;

  const sumOfOthers = total - long.distanceKm;
  // Pra ratio = X: long' = (X / (1-X)) × others
  // X=0.50 → long' = others
  const newLongDistance = Math.max(1, Math.round(
    (MAX_LONG_RUN_RATIO / (1 - MAX_LONG_RUN_RATIO)) * sumOfOthers * 10,
  ) / 10);

  logger.warn('plan.week.long_run_ratio.clamped', {
    rawLong: long.distanceKm,
    rawTotal: total,
    rawRatio: Math.round(ratio * 100) / 100,
    newLong: newLongDistance,
    sumOfOthers,
    ...ctx,
  });

  // Retorna nova lista com long substituído.
  return sessions.map((s, i) =>
    i === maxIdx ? { ...s, distanceKm: newLongDistance } : s,
  );
}

/**
 * Mapeia distância da prova → label canônico que deve aparecer no `type`
 * da sessão-alvo. Padroniza a copy ("Maratona" vs "42K Maratona" vs "Race
 * 42km" etc).
 */
const TARGET_SESSION_TYPE: Record<RaceDistanceKm, string> = {
  5: '5K',
  10: '10K',
  21: 'Meia Maratona',
  42: 'Maratona',
};

/**
 * Marca a ÚLTIMA sessão da ÚLTIMA semana como sessão-alvo:
 *  - `isTarget = true`
 *  - `type` = label canônico ("Maratona" pra 42K, "Meia Maratona" pra 21K…)
 *  - `distanceKm` = `raceDistanceKm` (isento do cap MAX_KM_PER_SESSION
 *    porque essa é a PROVA, não treino).
 *
 * Roda SÓ pra goalKind=race. Resolve o problema reportado: plano de
 * maratona terminando em 12km de "Maratona" — agora termina em 42km
 * mesmo (e se cap do nível impede, é porque a meta não cabe → bloqueado
 * antes pelos validators).
 */
export function markTargetSession(
  weeks: PlanWeek[],
  raceDistanceKm: RaceDistanceKm,
  ctx: { planId?: string; targetPaceMinKm?: string | null } = {},
): PlanWeek[] {
  if (weeks.length === 0) return weeks;
  const lastWeek = weeks[weeks.length - 1];
  if (lastWeek.sessions.length === 0) {
    logger.warn('plan.target_session.empty_last_week', { weekNumber: lastWeek.weekNumber, ...ctx });
    return weeks;
  }
  // Última sessão = maior dayOfWeek; se empate, última da array (já ordenada
  // por dayOfWeek antes deste sanitizer).
  const lastIdx = lastWeek.sessions.length - 1;
  const orig = lastWeek.sessions[lastIdx];
  const targetType = TARGET_SESSION_TYPE[raceDistanceKm];
  // Quando raceMode='improve_pace' + targetPaceMinKm informado, força o pace
  // alvo na sessão-meta (LLM ocasionalmente devolve pace mais lento ou ausente).
  const targetPace = ctx.targetPaceMinKm ?? orig.targetPace;
  const updatedSession = {
    ...orig,
    type: targetType,
    distanceKm: raceDistanceKm,
    targetPace,
    isTarget: true,
    notes: orig.notes && orig.notes.length > 0
      ? `[META] ${orig.notes}`
      : `[META] ${raceDistanceKm}K — sessão-prova: execute a distância completa no pace alvo do plano.`,
  };
  logger.info('plan.target_session.marked', {
    weekNumber: lastWeek.weekNumber,
    rawType: orig.type,
    rawDistanceKm: orig.distanceKm,
    targetType,
    targetDistanceKm: raceDistanceKm,
    ...ctx,
  });
  const updatedSessions = lastWeek.sessions.map((s, i) => i === lastIdx ? updatedSession : s);
  const updatedWeek = { ...lastWeek, sessions: updatedSessions };
  return weeks.map((w, i) => i === weeks.length - 1 ? updatedWeek : w);
}
