import { PlanWeek } from '../domain/plan.entity';

/**
 * Defensive layer pós-LLM: aplica paces coerentes nas sessões a partir dos
 * inputs do assessment.
 *
 *  - Quando `raceMode='improve_pace'` E `targetPaceMinKm` informado:
 *      * Sessão-meta (isTarget=true) → targetPace = targetPaceMinKm
 *      * Sessões de qualidade (Tempo, Tiros, Intervalado, Progressivo,
 *        Fartlek) nas semanas centrais (40-90% do total) → targetPace =
 *        targetPaceMinKm. Não sobrescreve se já está em ±15s do alvo.
 *
 *  - Quando `currentPaceMinKm` informado (= P):
 *      * Easy Run / Long Run → P + 45s/km (meio do range conversável)
 *      * Recovery → P + 75s/km (zona regenerativa)
 *      * Só seta quando o pace atual estiver fora da tolerância (não mexe
 *        em pace coerente; respeita o LLM quando ele entregou correto).
 *
 * Não altera Caminhada (pace próprio dela). No-op quando os respectivos
 * inputs são null.
 */

export interface EnforcePaceOp {
  scope: 'pace_target_meta' | 'pace_target_quality' | 'pace_easy' | 'pace_recovery';
  weekNumber: number;
  dayOfWeek: number;
  sessionType: string;
  from: string | undefined;
  to: string;
}

export interface EnforcePaceResult {
  weeks: PlanWeek[];
  ops: EnforcePaceOp[];
}

const TOLERANCE_S = 15; // ±15s/km do alvo = coerente, não sobrescreve

const QUALITY_KEYS = ['tempo', 'tiros', 'intervalado', 'progressivo', 'fartlek'];
const EASY_KEYS = ['easy', 'long run', 'longrun'];
const RECOVERY_KEYS = ['recovery', 'regener'];

function paceToSec(p: string | undefined): number | null {
  if (!p) return null;
  const m = /^(\d{1,2}):(\d{2})$/.exec(p.trim());
  if (!m) return null;
  return parseInt(m[1], 10) * 60 + parseInt(m[2], 10);
}

function secToPace(sec: number): string {
  // Total arredondado ANTES de separar (round(%60)→60 gerava "5:60").
  const total = Math.round(sec);
  const m = Math.floor(total / 60);
  const s = total % 60;
  return `${m}:${String(s).padStart(2, '0')}`;
}

function lc(s: string): string {
  return s.toLowerCase();
}

function isQuality(type: string): boolean {
  const t = lc(type);
  return QUALITY_KEYS.some((k) => t.includes(k));
}

function isEasy(type: string): boolean {
  const t = lc(type);
  return EASY_KEYS.some((k) => t.includes(k));
}

function isRecovery(type: string): boolean {
  const t = lc(type);
  return RECOVERY_KEYS.some((k) => t.includes(k));
}

export function enforceTargetPace(
  weeks: PlanWeek[],
  raceMode: 'complete' | 'improve_pace' | null | undefined,
  targetPaceMinKm: string | null | undefined,
  currentPaceMinKm: string | null | undefined,
): EnforcePaceResult {
  const ops: EnforcePaceOp[] = [];
  const targetSec = paceToSec(targetPaceMinKm ?? undefined);
  const currentSec = paceToSec(currentPaceMinKm ?? undefined);
  const applyTarget = raceMode === 'improve_pace' && targetSec != null;

  const totalWeeks = weeks.length;
  const centralStart = Math.floor(totalWeeks * 0.4);
  const centralEnd = Math.ceil(totalWeeks * 0.9);

  const out: PlanWeek[] = weeks.map((w, idx) => {
    const isCentral = idx >= centralStart && idx < centralEnd;
    const newSessions = w.sessions.map((s) => {
      const curSec = paceToSec(s.targetPace);

      // 1) Sessão-meta: pace = target
      if (applyTarget && s.isTarget) {
        const newPace = secToPace(targetSec!);
        if (curSec == null || Math.abs(curSec - targetSec!) > TOLERANCE_S) {
          ops.push({
            scope: 'pace_target_meta',
            weekNumber: w.weekNumber,
            dayOfWeek: s.dayOfWeek,
            sessionType: s.type,
            from: s.targetPace,
            to: newPace,
          });
          return { ...s, targetPace: newPace };
        }
        return s;
      }

      // 2) Qualidades em semanas centrais
      if (applyTarget && isCentral && isQuality(s.type)) {
        const newPace = secToPace(targetSec!);
        if (curSec == null || Math.abs(curSec - targetSec!) > TOLERANCE_S) {
          ops.push({
            scope: 'pace_target_quality',
            weekNumber: w.weekNumber,
            dayOfWeek: s.dayOfWeek,
            sessionType: s.type,
            from: s.targetPace,
            to: newPace,
          });
          return { ...s, targetPace: newPace };
        }
        return s;
      }

      // 3) Easy / Long Run: P + 45s (centro do range conversável)
      if (currentSec != null && isEasy(s.type)) {
        const want = currentSec + 45;
        if (curSec == null || Math.abs(curSec - want) > TOLERANCE_S) {
          const newPace = secToPace(want);
          ops.push({
            scope: 'pace_easy',
            weekNumber: w.weekNumber,
            dayOfWeek: s.dayOfWeek,
            sessionType: s.type,
            from: s.targetPace,
            to: newPace,
          });
          return { ...s, targetPace: newPace };
        }
        return s;
      }

      // 4) Recovery: P + 75s
      if (currentSec != null && isRecovery(s.type)) {
        const want = currentSec + 75;
        if (curSec == null || Math.abs(curSec - want) > TOLERANCE_S) {
          const newPace = secToPace(want);
          ops.push({
            scope: 'pace_recovery',
            weekNumber: w.weekNumber,
            dayOfWeek: s.dayOfWeek,
            sessionType: s.type,
            from: s.targetPace,
            to: newPace,
          });
          return { ...s, targetPace: newPace };
        }
        return s;
      }

      return s;
    });
    return { ...w, sessions: newSessions };
  });

  return { weeks: out, ops };
}
