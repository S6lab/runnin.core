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
 * Marca a sessão-prova na ÚLTIMA semana, alinhada ao dia da semana do raceDate
 * (raceDayOfWeek = 1..7, Mon..Sun). Comportamento:
 *
 *   1. Se raceDayOfWeek vier: insere/atualiza sessão exatamente nesse dia,
 *      remove qualquer sessão com dayOfWeek > raceDayOfWeek (não treinamos
 *      DEPOIS da prova) e ordena por dayOfWeek.
 *   2. Sem raceDayOfWeek (fallback legado): substitui a última sessão da
 *      última semana — mesmo comportamento antigo. Mantido pra suportar
 *      planos criados antes da migração.
 *
 * Sessão-alvo final tem:
 *   - `isTarget = true`
 *   - `type` = label canônico ("Maratona" pra 42K, "Meia Maratona" pra 21K…)
 *   - `distanceKm` = `raceDistanceKm` (isento do cap MAX_KM_PER_SESSION
 *     porque essa é a PROVA, não treino).
 *
 * Resolve o bug reportado: prova de domingo aparecia na sexta porque o LLM
 * tinha treinos Mon/Wed/Fri/Sat e o código substituía Sat. Agora insere no
 * domingo e descarta sessões pós-prova.
 */
export function markTargetSession(
  weeks: PlanWeek[],
  raceDistanceKm: RaceDistanceKm,
  ctx: { planId?: string; targetPaceMinKm?: string | null; raceDayOfWeek?: number } = {},
): PlanWeek[] {
  if (weeks.length === 0) return weeks;
  const lastWeek = weeks[weeks.length - 1];
  const targetType = TARGET_SESSION_TYPE[raceDistanceKm];
  const raceDow = ctx.raceDayOfWeek;

  // ─── Caminho legado: sem raceDayOfWeek ────────────────────────────────
  if (!raceDow) {
    if (lastWeek.sessions.length === 0) {
      logger.warn('plan.target_session.empty_last_week', { weekNumber: lastWeek.weekNumber, planId: ctx.planId });
      return weeks;
    }
    const lastIdx = lastWeek.sessions.length - 1;
    const orig = lastWeek.sessions[lastIdx];
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
      mode: 'legacy_last',
      rawType: orig.type,
      rawDistanceKm: orig.distanceKm,
      targetType,
      targetDistanceKm: raceDistanceKm,
      planId: ctx.planId,
    });
    const updatedSessions = lastWeek.sessions.map((s, i) => i === lastIdx ? updatedSession : s);
    const updatedWeek = { ...lastWeek, sessions: updatedSessions };
    return weeks.map((w, i) => i === weeks.length - 1 ? updatedWeek : w);
  }

  // ─── Caminho novo: raceDayOfWeek presente ─────────────────────────────
  // 1. Filtra sessões com dayOfWeek > raceDow (não há treino DEPOIS da prova).
  const droppedPostRace = lastWeek.sessions.filter(s => s.dayOfWeek > raceDow);
  const keptSessions = lastWeek.sessions.filter(s => s.dayOfWeek <= raceDow);

  // 2. Busca sessão existente no raceDow. Se achou, substitui; senão, insere.
  const existingIdx = keptSessions.findIndex(s => s.dayOfWeek === raceDow);
  const templateSession = existingIdx >= 0
    ? keptSessions[existingIdx]
    : (keptSessions[keptSessions.length - 1] ?? {
        dayOfWeek: raceDow,
        type: 'Easy',
        distanceKm: 0,
        durationMin: 0,
        targetPace: null,
        notes: null,
        isExecuted: false,
        executedRunId: null,
      });
  const targetPace = ctx.targetPaceMinKm ?? templateSession.targetPace;
  const targetSession = {
    ...templateSession,
    dayOfWeek: raceDow,
    type: targetType,
    distanceKm: raceDistanceKm,
    targetPace,
    isTarget: true,
    notes: templateSession.notes && templateSession.notes.length > 0 && existingIdx >= 0
      ? `[META] ${templateSession.notes}`
      : `[META] ${raceDistanceKm}K — sessão-prova: execute a distância completa no pace alvo do plano.`,
  };

  // 3. Monta lista final: sessões mantidas (sem a do dia da prova) + targetSession,
  //    ordenadas por dayOfWeek.
  const withoutTargetDay = keptSessions.filter(s => s.dayOfWeek !== raceDow);
  const finalSessions = [...withoutTargetDay, targetSession]
    .sort((a, b) => a.dayOfWeek - b.dayOfWeek);

  logger.info('plan.target_session.marked', {
    weekNumber: lastWeek.weekNumber,
    mode: existingIdx >= 0 ? 'replaced_existing' : 'inserted_new',
    raceDayOfWeek: raceDow,
    targetType,
    targetDistanceKm: raceDistanceKm,
    droppedPostRaceCount: droppedPostRace.length,
    droppedPostRaceDays: droppedPostRace.map(s => s.dayOfWeek),
    planId: ctx.planId,
  });

  const updatedWeek = { ...lastWeek, sessions: finalSessions };
  return weeks.map((w, i) => i === weeks.length - 1 ? updatedWeek : w);
}
