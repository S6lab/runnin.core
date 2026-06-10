// Definições dos badges em código — pure functions de avaliação.
// Adicionar badge novo = adicionar entry aqui e re-deploy.
//
// Cada definição recebe contexto (run completa + lifetime stats + plano)
// e retorna `null` se ainda não desbloqueou OU `{stats, context, chip}` se
// desbloqueou agora.

import { Run } from '@modules/runs/domain/run.entity';
import { Badge, BadgeCategory, BadgeStatsSnapshot } from './badge.entity';

export interface BadgeEvalContext {
  uid: string;
  /** Run que acabou de completar (gatilho de eval). Pode ser null no eval
   *  de report (cron) ou retroativo histórico. */
  currentRun?: Run;
  /** Todas as runs do user, ordenadas por createdAt asc. */
  allRuns: Run[];
  /** Já desbloqueados (badgeIds) — evita re-disparar. */
  alreadyUnlocked: Set<string>;
  /** Triggered manualmente (relatório semanal/mensal disponível). */
  reportTrigger?: { kind: 'weekly' | 'monthly'; weekStart?: string; monthKey?: string };
}

export interface BadgeUnlockResult {
  primaryDisplay: string;
  primaryUnit?: string;
  stats: BadgeStatsSnapshot;
  context?: Badge['context'];
  badgeChip?: string;
}

export interface BadgeDefinition {
  badgeId: string;
  category: BadgeCategory;
  title: string;
  subtitle: string;
  description?: string;
  /** Retorna o unlock result se desbloqueou agora; null caso contrário. */
  evaluate: (ctx: BadgeEvalContext) => BadgeUnlockResult | null;
}

// ── Helpers ─────────────────────────────────────────────────────────────

function totalKm(runs: Run[]): number {
  return runs.reduce((s, r) => s + (r.distanceM ?? 0) / 1000, 0);
}

function fmtPace(paceMinKm?: string | null): string | undefined {
  return paceMinKm ?? undefined;
}

function paceToSeconds(pace?: string): number | null {
  if (!pace) return null;
  const m = /^(\d+):(\d{2})/.exec(pace);
  if (!m) return null;
  return parseInt(m[1]!, 10) * 60 + parseInt(m[2]!, 10);
}

function ymd(ts: string | number | undefined): string | undefined {
  if (!ts) return undefined;
  const d = new Date(ts);
  if (Number.isNaN(d.getTime())) return undefined;
  return d.toISOString().slice(0, 10);
}

function runDateLocal(run: Run): Date {
  // createdAt é string ISO; usamos UTC mesmo. Streak por dia UTC é
  // aproximação aceitável (mismatch só em corridas no fuso entre 21h-3h).
  return new Date(run.createdAt as string);
}

function currentStreakDays(allRuns: Run[]): number {
  if (allRuns.length === 0) return 0;
  const days = new Set<string>();
  for (const r of allRuns) {
    const ts = ymd(r.createdAt as string);
    if (ts) days.add(ts);
  }
  // Conta de hoje pra trás, dia a dia, até encontrar buraco.
  let streak = 0;
  const today = new Date();
  for (let i = 0; i < 365; i++) {
    const check = new Date(today);
    check.setUTCDate(today.getUTCDate() - i);
    const key = check.toISOString().slice(0, 10);
    if (days.has(key)) streak++;
    else if (i === 0) continue; // Hoje sem corrida ainda? Olha ontem.
    else break;
  }
  return streak;
}

function bestRunByDistance(allRuns: Run[], minKm: number): Run | null {
  return allRuns
    .filter((r) => (r.distanceM ?? 0) / 1000 >= minKm)
    .sort((a, b) => (a.avgPace ?? '99:99').localeCompare(b.avgPace ?? '99:99'))[0] ?? null;
}

function buildStatsFromRun(run: Run): BadgeStatsSnapshot {
  return {
    distanceKm: run.distanceM ? Math.round((run.distanceM / 1000) * 10) / 10 : undefined,
    durationS: run.durationS,
    paceMinKm: fmtPace(run.avgPace),
    avgBpm: run.avgBpm,
    maxBpm: run.maxBpm,
  };
}

// ── Categoria: PRIMEIRAS VEZES (one-shot) ───────────────────────────────

const FIRST_RUN: BadgeDefinition = {
  badgeId: 'first_run',
  category: 'first',
  title: 'Primeira Corrida',
  subtitle: 'O começo de tudo',
  description: 'Você completou sua primeira corrida no Runnin.',
  evaluate: ({ allRuns }) => {
    const first = allRuns[0];
    if (!first) return null;
    return {
      primaryDisplay: '01',
      stats: buildStatsFromRun(first),
      context: { runId: first.id },
      badgeChip: 'MARCO HISTÓRICO',
    };
  },
};

const FIRST_5K: BadgeDefinition = {
  badgeId: 'first_5k_run',
  category: 'first',
  title: 'Primeiros 5 km',
  subtitle: 'Marcou os primeiros 5 km em uma única corrida',
  evaluate: ({ allRuns }) => {
    const r = allRuns.find((x) => (x.distanceM ?? 0) >= 5000);
    if (!r) return null;
    return {
      primaryDisplay: '5K',
      stats: buildStatsFromRun(r),
      context: { runId: r.id },
      badgeChip: 'PRIMEIROS 5 KM',
    };
  },
};

const FIRST_10K: BadgeDefinition = {
  badgeId: 'first_10k_run',
  category: 'first',
  title: 'Primeiros 10 km',
  subtitle: 'Marcou os primeiros 10 km em uma única corrida',
  evaluate: ({ allRuns }) => {
    const r = allRuns.find((x) => (x.distanceM ?? 0) >= 10000);
    if (!r) return null;
    return {
      primaryDisplay: '10K',
      stats: buildStatsFromRun(r),
      context: { runId: r.id },
      badgeChip: 'PRIMEIROS 10 KM',
    };
  },
};

const FIRST_LONG_RUN: BadgeDefinition = {
  badgeId: 'first_long_run',
  category: 'first',
  title: 'Primeira Long Run',
  subtitle: 'Acima de 10 km em uma corrida',
  evaluate: ({ allRuns }) => {
    const r = allRuns.find((x) => (x.distanceM ?? 0) > 10000);
    if (!r) return null;
    return {
      primaryDisplay: `${((r.distanceM ?? 0) / 1000).toFixed(1)}`,
      primaryUnit: 'km',
      stats: buildStatsFromRun(r),
      context: { runId: r.id },
      badgeChip: 'LONG RUN',
    };
  },
};

const FIRST_HALF_MARATHON: BadgeDefinition = {
  badgeId: 'first_half_marathon',
  category: 'first',
  title: 'Primeira Meia Maratona',
  subtitle: '21.1 km em uma corrida',
  evaluate: ({ allRuns }) => {
    const r = allRuns.find((x) => (x.distanceM ?? 0) >= 21100);
    if (!r) return null;
    return {
      primaryDisplay: '21.1',
      primaryUnit: 'km',
      stats: buildStatsFromRun(r),
      context: { runId: r.id },
      badgeChip: 'MEIA MARATONA',
    };
  },
};

const FIRST_MARATHON: BadgeDefinition = {
  badgeId: 'first_marathon',
  category: 'first',
  title: 'Primeira Maratona',
  subtitle: '42.2 km em uma corrida',
  evaluate: ({ allRuns }) => {
    const r = allRuns.find((x) => (x.distanceM ?? 0) >= 42200);
    if (!r) return null;
    return {
      primaryDisplay: '42.2',
      primaryUnit: 'km',
      stats: buildStatsFromRun(r),
      context: { runId: r.id },
      badgeChip: 'MARATONA',
    };
  },
};

const FIRST_PLAN_RUN: BadgeDefinition = {
  badgeId: 'first_plan_run',
  category: 'first',
  title: 'Primeira do Plano',
  subtitle: 'Primeira sessão planejada concluída',
  evaluate: ({ allRuns }) => {
    const r = allRuns.find((x) => x.planSessionId);
    if (!r) return null;
    return {
      primaryDisplay: '01',
      stats: buildStatsFromRun(r),
      context: { runId: r.id },
      badgeChip: 'PLANO INICIADO',
    };
  },
};

function firstByHourRange(label: string, fromH: number, toH: number, chip: string): BadgeDefinition {
  const slug = `first_${label}_run`;
  return {
    badgeId: slug,
    category: 'first',
    title: `Primeira corrida ${chip.toLowerCase()}`,
    subtitle: `Corrida iniciada entre ${fromH}h e ${toH}h`,
    evaluate: ({ allRuns }) => {
      const r = allRuns.find((x) => {
        const d = runDateLocal(x);
        const h = d.getUTCHours();
        if (fromH <= toH) return h >= fromH && h < toH;
        return h >= fromH || h < toH; // janela que cruza meia-noite
      });
      if (!r) return null;
      return {
        primaryDisplay: '01',
        stats: buildStatsFromRun(r),
        context: { runId: r.id },
        badgeChip: chip,
      };
    },
  };
}

const FIRST_DAWN_RUN = firstByHourRange('dawn', 4, 8, 'AMANHECER');
const FIRST_NIGHT_RUN = firstByHourRange('night', 20, 23, 'NOTURNA');
const FIRST_MIDNIGHT_RUN = firstByHourRange('midnight', 0, 4, 'MADRUGADA');

// ── Categoria: DISTÂNCIA ACUMULADA ──────────────────────────────────────

function cumulativeDistance(target: number, label: string): BadgeDefinition {
  return {
    badgeId: `cumulative_${target}k`,
    category: 'distance_total',
    title: `${target} km acumulados`,
    subtitle: `Você alcançou ${target} km totais no Runnin`,
    evaluate: ({ allRuns }) => {
      const km = totalKm(allRuns);
      if (km < target) return null;
      return {
        primaryDisplay: `${target}`,
        primaryUnit: 'km',
        stats: {
          distanceKm: Math.round(km * 10) / 10,
          extra: { target, runsTotal: allRuns.length },
        },
        badgeChip: label,
      };
    },
  };
}

const CUM_10K = cumulativeDistance(10, 'ACUMULADO 10K');
const CUM_50K = cumulativeDistance(50, 'ACUMULADO 50K');
const CUM_100K = cumulativeDistance(100, 'ACUMULADO 100K');
const CUM_250K = cumulativeDistance(250, 'ACUMULADO 250K');
const CUM_500K = cumulativeDistance(500, 'ACUMULADO 500K');
const CUM_1000K = cumulativeDistance(1000, 'ACUMULADO 1000K');

// ── Categoria: DISTÂNCIA ÚNICA (PRs por run) ────────────────────────────

function singleRunDistance(target: number, label: string): BadgeDefinition {
  return {
    badgeId: `single_run_${target}k`,
    category: 'distance_run',
    title: `${target} km em uma corrida`,
    subtitle: `Você completou ${target} km em uma única corrida`,
    evaluate: ({ allRuns }) => {
      const r = allRuns.find((x) => (x.distanceM ?? 0) >= target * 1000);
      if (!r) return null;
      return {
        primaryDisplay: `${target}`,
        primaryUnit: 'km',
        stats: buildStatsFromRun(r),
        context: { runId: r.id },
        badgeChip: label,
      };
    },
  };
}

const RUN_15K = singleRunDistance(15, 'DISTÂNCIA ÚNICA 15K');
const RUN_30K = singleRunDistance(30, 'DISTÂNCIA ÚNICA 30K');

// ── Categoria: STREAKS ──────────────────────────────────────────────────

function streakDays(target: number, label: string): BadgeDefinition {
  return {
    badgeId: `streak_${target}_days`,
    category: 'streak',
    title: `${target} dias seguidos`,
    subtitle: `Você correu ${target} dias consecutivos`,
    evaluate: ({ allRuns }) => {
      const streak = currentStreakDays(allRuns);
      if (streak < target) return null;
      return {
        primaryDisplay: `${target}`,
        primaryUnit: target === 1 ? 'dia' : 'dias',
        stats: {
          distanceKm: Math.round(totalKm(allRuns) * 10) / 10,
          extra: { streak, target },
        },
        badgeChip: label,
      };
    },
  };
}

const STREAK_3 = streakDays(3, 'STREAK 3 DIAS');
const STREAK_7 = streakDays(7, 'STREAK 7 DIAS');
const STREAK_14 = streakDays(14, 'STREAK 14 DIAS');
const STREAK_30 = streakDays(30, 'STREAK 30 DIAS');
const STREAK_60 = streakDays(60, 'STREAK 60 DIAS');
const STREAK_100 = streakDays(100, 'STREAK 100 DIAS');

// ── Categoria: PACE PRs ─────────────────────────────────────────────────

function paceUnderThreshold(thresholdSec: number, label: string): BadgeDefinition {
  const mm = Math.floor(thresholdSec / 60);
  const ss = thresholdSec % 60;
  const labelPace = `${mm}:${ss.toString().padStart(2, '0')}`;
  return {
    badgeId: `pace_sub_${mm}_${ss}`,
    category: 'pace',
    title: `Sub-${labelPace}/km`,
    subtitle: `Primeira corrida com pace médio abaixo de ${labelPace}/km`,
    evaluate: ({ allRuns }) => {
      const r = allRuns.find((x) => {
        const p = paceToSeconds(x.avgPace);
        return p !== null && p < thresholdSec;
      });
      if (!r) return null;
      return {
        primaryDisplay: r.avgPace ?? labelPace,
        primaryUnit: '/km',
        stats: buildStatsFromRun(r),
        context: { runId: r.id },
        badgeChip: label,
      };
    },
  };
}

// Escala 30s entre 7:00 e 3:30/km.
const PACE_BADGES: BadgeDefinition[] = [];
for (let total = 420; total >= 210; total -= 30) {
  const mm = Math.floor(total / 60);
  const ss = total % 60;
  PACE_BADGES.push(paceUnderThreshold(total, `SUB-${mm}:${ss.toString().padStart(2, '0')}`));
}

const BEST_SPLIT_PR: BadgeDefinition = {
  badgeId: 'best_split_pr',
  category: 'pace',
  title: 'Melhor Split',
  subtitle: 'Novo recorde de pace de 1 km dentro de uma corrida',
  evaluate: () => null, // TODO: precisa de splits agregados (TF 78)
};

const BEST_AVG_PACE_PR: BadgeDefinition = {
  badgeId: 'best_avg_pace_pr',
  category: 'pace',
  title: 'Melhor pace médio',
  subtitle: 'Novo recorde de pace médio em treino',
  evaluate: ({ allRuns }) => {
    // Considera corridas >= 5km pra evitar PR de runs muito curtas.
    const validRuns = allRuns.filter((r) => (r.distanceM ?? 0) >= 5000 && r.avgPace);
    if (validRuns.length === 0) return null;
    const best = bestRunByDistance(validRuns, 5);
    if (!best) return null;
    return {
      primaryDisplay: best.avgPace ?? '—',
      primaryUnit: '/km',
      stats: buildStatsFromRun(best),
      context: { runId: best.id },
      badgeChip: 'MELHOR PACE EM TREINO',
    };
  },
};

// ── Categoria: RELATÓRIO (semanal/mensal) ───────────────────────────────

const WEEKLY_REPORT: BadgeDefinition = {
  badgeId: 'weekly_report_available',
  category: 'report',
  title: 'Relatório semanal',
  subtitle: 'Sua revisão semanal está pronta',
  evaluate: ({ reportTrigger, allRuns }) => {
    if (reportTrigger?.kind !== 'weekly') return null;
    const weekStart = reportTrigger.weekStart;
    if (!weekStart) return null;
    // Stats da semana
    const start = new Date(weekStart);
    const end = new Date(start);
    end.setUTCDate(end.getUTCDate() + 7);
    const weekRuns = allRuns.filter((r) => {
      const d = new Date(r.createdAt as string);
      return d >= start && d < end;
    });
    const weekKm = totalKm(weekRuns);
    return {
      primaryDisplay: weekKm.toFixed(1),
      primaryUnit: 'km',
      stats: {
        weekKm: Math.round(weekKm * 10) / 10,
        distanceKm: Math.round(weekKm * 10) / 10,
        durationS: weekRuns.reduce((s, r) => s + (r.durationS ?? 0), 0),
        extra: { runsCount: weekRuns.length, weekStart },
      },
      context: { weekStart },
      badgeChip: `SEMANA ${formatWeekRange(start)}`,
    };
  },
};

function formatWeekRange(start: Date): string {
  const end = new Date(start);
  end.setUTCDate(end.getUTCDate() + 6);
  const fmt = (d: Date) => `${d.getUTCDate()}/${d.getUTCMonth() + 1}`;
  return `${fmt(start)} – ${fmt(end)}`;
}

const MONTHLY_REPORT: BadgeDefinition = {
  badgeId: 'monthly_report_available',
  category: 'report',
  title: 'Relatório mensal',
  subtitle: 'Resumo do mês fechado',
  evaluate: ({ reportTrigger, allRuns }) => {
    if (reportTrigger?.kind !== 'monthly') return null;
    const monthKey = reportTrigger.monthKey;
    if (!monthKey) return null;
    const [yearStr, monthStr] = monthKey.split('-');
    const year = parseInt(yearStr!, 10);
    const month = parseInt(monthStr!, 10);
    const monthRuns = allRuns.filter((r) => {
      const d = new Date(r.createdAt as string);
      return d.getUTCFullYear() === year && d.getUTCMonth() + 1 === month;
    });
    const monthKm = totalKm(monthRuns);
    return {
      primaryDisplay: monthKm.toFixed(1),
      primaryUnit: 'km',
      stats: {
        monthKm: Math.round(monthKm * 10) / 10,
        distanceKm: Math.round(monthKm * 10) / 10,
        durationS: monthRuns.reduce((s, r) => s + (r.durationS ?? 0), 0),
        extra: { runsCount: monthRuns.length, monthKey },
      },
      context: { monthKey },
      badgeChip: monthKey,
    };
  },
};

// ── Registry ────────────────────────────────────────────────────────────

export const BADGE_DEFINITIONS: BadgeDefinition[] = [
  // Primeiras vezes
  FIRST_RUN,
  FIRST_PLAN_RUN,
  FIRST_DAWN_RUN,
  FIRST_NIGHT_RUN,
  FIRST_MIDNIGHT_RUN,
  FIRST_LONG_RUN,
  FIRST_5K,
  FIRST_10K,
  FIRST_HALF_MARATHON,
  FIRST_MARATHON,
  // Acumulada
  CUM_10K,
  CUM_50K,
  CUM_100K,
  CUM_250K,
  CUM_500K,
  CUM_1000K,
  // Distância única (PR por run)
  RUN_15K,
  RUN_30K,
  // Streaks
  STREAK_3,
  STREAK_7,
  STREAK_14,
  STREAK_30,
  STREAK_60,
  STREAK_100,
  // Pace
  BEST_SPLIT_PR,
  BEST_AVG_PACE_PR,
  ...PACE_BADGES,
  // Reports
  WEEKLY_REPORT,
  MONTHLY_REPORT,
];

export function getBadgeDefinition(badgeId: string): BadgeDefinition | undefined {
  return BADGE_DEFINITIONS.find((d) => d.badgeId === badgeId);
}
