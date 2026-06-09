import { v4 as uuid } from 'uuid';
import { Plan, PlanSession, PlanWeek } from '../domain/plan.entity';
import { buildExecutionSegments } from './build-execution-segments';
import { enforceLevelTypeAllowlist } from './checkpoint-shared';
import { getRoteiroTemplates } from '@shared/knowledge/running/roteiro-templates.store';

/**
 * Hidrata recheio das sessões pós-revisão do LLM.
 *
 * Problema: o schema do LLM checkpoint cospe `{ dayOfWeek, type, distanceKm,
 * targetPace, notes }` mais ou menos. Frequentemente sem `executionSegments`
 * (roteiro km-a-km), `hydrationLiters`, `nutritionPre/Post`. UI vê
 * `executionSegments.length < 2` e renderiza placeholder/locked.
 *
 * Cobertura:
 *  - `executionSegments` via `buildExecutionSegments` (regra determinística
 *    a partir do tipo + roteiro-templates do Firestore).
 *  - `hydrationLiters` via `weight × 0.035` (cap 3.5L).
 *  - `nutritionPre/Post` via defaults por tipo de sessão.
 *  - `targetPace` derivado do `level` se ausente (fallback conservador).
 *  - `id` via uuid se ausente.
 *
 * E ainda força `detailLevel`:
 *  - weeks current+1 e current+2 → `'full'` (UI desbloqueia detalhe).
 *  - weeks current+3 em diante → `'skeleton'` (mantém locked, libera no próximo cron).
 *
 * E fallback narrative determinístico se LLM omitir (sem segundo LLM call).
 */
export async function hydrateRevisedSessions(
  weeks: PlanWeek[],
  ctx: {
    currentWeekNumber: number;
    profile: { weight?: number; level?: string } | null;
    plan: Plan;
  },
): Promise<PlanWeek[]> {
  const tpl = await getRoteiroTemplates();
  const weight = ctx.profile?.weight;
  const level = ctx.profile?.level;
  const isRace = !!ctx.plan.raceDate && !!ctx.plan.raceDayOfWeek;
  const raceWeekNumber = ctx.plan.weeksCount;
  const taperWeekNumber = raceWeekNumber - 1;

  return weeks.map((w) => {
    // Passado e race/taper: respeita o que veio do enforce (não toca).
    if (w.weekNumber <= ctx.currentWeekNumber) return w;
    if (isRace && (w.weekNumber === raceWeekNumber || w.weekNumber === taperWeekNumber)) return w;

    const isFull = w.weekNumber === ctx.currentWeekNumber + 1 || w.weekNumber === ctx.currentWeekNumber + 2;
    const detailLevel = isFull ? 'full' : 'skeleton';

    const sessions = isFull
      ? w.sessions.map((s) => hydrateSession(s, tpl, weight, level))
      : w.sessions;

    return {
      ...w,
      detailLevel,
      sessions,
      narrative: w.narrative && w.narrative.trim().length > 0
        ? w.narrative
        : fallbackNarrative(w),
      focus: w.focus && w.focus.trim().length > 0 ? w.focus : fallbackFocus(w),
      blockName: w.blockName && w.blockName.trim().length > 0 ? w.blockName : fallbackBlockName(w),
      objective: w.objective && w.objective.trim().length > 0 ? w.objective : fallbackObjective(w),
      targets: w.targets && w.targets.length > 0 ? w.targets : fallbackTargets(w),
    };
  });
}

function hydrateSession(
  s: PlanSession,
  tpl: Awaited<ReturnType<typeof getRoteiroTemplates>>,
  weight: number | undefined,
  level: string | undefined,
): PlanSession {
  const id = s.id && s.id.length > 0 ? s.id : uuid();
  // Enforce allowlist por nível ANTES de gerar segments — Fartlek/Tiros pra
  // iniciante viram Easy/Progressivo, e o roteiro é gerado pro tipo correto.
  const { type: safeType } = enforceLevelTypeAllowlist(s.type, level, { dayOfWeek: s.dayOfWeek });
  const safeS = safeType === s.type ? s : { ...s, type: safeType };
  const hasSegments = (s.executionSegments?.length ?? 0) >= 2 && safeType === s.type;
  const executionSegments = hasSegments
    ? safeS.executionSegments
    : buildExecutionSegments({ ...safeS, id }, tpl);

  const hydrationLiters = s.hydrationLiters && s.hydrationLiters > 0
    ? s.hydrationLiters
    : computeHydration(weight, s.distanceKm);

  const nutritionPre = s.nutritionPre && s.nutritionPre.trim().length > 0
    ? s.nutritionPre
    : defaultPreNutrition(safeType);
  const nutritionPost = s.nutritionPost && s.nutritionPost.trim().length > 0
    ? s.nutritionPost
    : defaultPostNutrition(safeType);

  const targetPace = s.targetPace && s.targetPace.length > 0
    ? s.targetPace
    : defaultTargetPace(safeType, level);

  const notes = s.notes && s.notes.trim().length > 0 && safeType === s.type
    ? s.notes
    : defaultNotes(safeType);

  return {
    ...safeS,
    id,
    executionSegments,
    hydrationLiters,
    nutritionPre,
    nutritionPost,
    targetPace,
    notes,
  };
}

function computeHydration(weight: number | undefined, distanceKm: number): number {
  // Regra: peso × 0.035L. Sem peso: usa default 2.0L pra distância média ou
  // 1.5L pra distâncias curtas. Cap 3.5L.
  if (typeof weight !== 'number' || weight <= 0) {
    if (distanceKm <= 4) return 1.5;
    if (distanceKm <= 8) return 2.0;
    return 2.5;
  }
  return Math.min(3.5, Math.round(weight * 0.035 * 10) / 10);
}

function defaultPreNutrition(type: string): string {
  const t = type.toLowerCase();
  if (t.includes('long') || t.includes('tempo')) {
    return 'Banana com pasta de amendoim + café 45min antes — glicogênio carregado pra sessão longa.';
  }
  if (t.includes('tiro') || t.includes('interval') || t.includes('fartlek')) {
    return 'Pão integral com mel + café 30-45min antes — energia rápida pra qualidade.';
  }
  if (t.includes('recovery') || t.includes('caminhada')) {
    return 'Fruta + chá 20min antes — o suficiente, sem peso no estômago.';
  }
  return 'Lanche leve (banana ou pão integral com mel) 30-45min antes — combustível pronto sem peso.';
}

function defaultPostNutrition(type: string): string {
  const t = type.toLowerCase();
  if (t.includes('long')) {
    return 'Refeição completa em 30min: proteína (ovo/frango) + carbo (arroz/batata) + fruta. Janela anabólica importa.';
  }
  if (t.includes('tiro') || t.includes('interval')) {
    return 'Shake proteico ou iogurte com frutas em 30min + refeição completa em 1h.';
  }
  if (t.includes('recovery') || t.includes('caminhada')) {
    return 'Hidratação + fruta. Não exige reposição grande — foco é recuperação ativa.';
  }
  return 'Refeição balanceada em até 1h: proteína + carbo + hidratação reforçada.';
}

function defaultTargetPace(type: string, level: string | undefined): string {
  const t = type.toLowerCase();
  const lvl = (level ?? 'iniciante').toLowerCase();
  // Tabela conservadora pra fallback. LLM normalmente devolve, isso só pra não deixar vazio.
  if (t.includes('tiro') || t.includes('interval')) return lvl === 'iniciante' ? '5:30' : '4:45';
  if (t.includes('tempo')) return lvl === 'iniciante' ? '6:00' : '5:15';
  if (t.includes('long')) return lvl === 'iniciante' ? '7:00' : '6:00';
  if (t.includes('recovery')) return lvl === 'iniciante' ? '7:30' : '6:45';
  if (t.includes('caminhada')) return '10:00';
  // Easy / Fartlek / Progressivo defaults
  return lvl === 'iniciante' ? '6:45' : '5:45';
}

function defaultNotes(type: string): string {
  const t = type.toLowerCase();
  if (t.includes('long')) return 'Long run — base aeróbica e resistência. Pace controlado, conversa possível. Sentiu fadiga forte? Reduz pace antes de parar.';
  if (t.includes('tiro') || t.includes('interval')) return 'Sessão de qualidade — alterna esforço forte com recuperação ativa. Foco em forma; pace de tiro só se sentir pronto.';
  if (t.includes('tempo')) return 'Tempo run — pace controlado próximo ao limiar. Respiração ritmada, sem aceleração no final.';
  if (t.includes('recovery')) return 'Recovery — pace bem leve, foco é REMOVER fadiga. Se BPM subir, anda alguns minutos.';
  if (t.includes('caminhada')) return 'Caminhada — base aeróbica de baixo impacto. Postura ereta, passada firme. Ouvir o corpo.';
  return 'Easy run — base aeróbica em zona conversável. Forma > pace. Hidrate antes e durante.';
}

function fallbackNarrative(w: PlanWeek): string {
  const totalKm = w.sessions.reduce((s, x) => s + (x.distanceKm ?? 0), 0);
  const n = w.sessions.length;
  return `Semana ${w.weekNumber} — ${n} sessões totalizando ${totalKm.toFixed(1)}km. Foco em consistência e consciência do esforço.`;
}

function fallbackFocus(w: PlanWeek): string {
  const totalKm = w.sessions.reduce((s, x) => s + (x.distanceKm ?? 0), 0);
  if (totalKm < 10) return 'Recuperação · Reset';
  if (totalKm < 20) return 'Base · Consistência';
  if (totalKm < 30) return 'Build · Volume';
  return 'Build · Resistência';
}

function fallbackBlockName(w: PlanWeek): string {
  return `Semana ${w.weekNumber} · Construção`;
}

function fallbackObjective(w: PlanWeek): string {
  const n = w.sessions.length;
  return `Completar as ${n} sessões respeitando paces alvo e descansando entre treinos.`;
}

function fallbackTargets(w: PlanWeek): string[] {
  const totalKm = w.sessions.reduce((s, x) => s + (x.distanceKm ?? 0), 0);
  return [
    `${w.sessions.length} sessões totalizando ${totalKm.toFixed(1)}km`,
    'Hidratação reforçada e sono mínimo 7h por noite',
  ];
}
