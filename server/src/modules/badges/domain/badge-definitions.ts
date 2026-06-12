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

/** Quote curta baseada nos dados reais da run pra badges FIRST_*. */
function firstRunCoachQuote(run: Run, kind: string): string {
  const km = run.distanceM ? (run.distanceM / 1000).toFixed(1) : '?';
  const pace = run.avgPace ?? '—';
  return `${kind} concluído: ${km}km a ${pace}/km. Esse é o registro real — ` +
         `a partir daqui o coach mede contra você mesmo.`;
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
    const stats = buildStatsFromRun(first);
    stats.extra = {
      ...(stats.extra ?? {}),
      coachQuote: firstRunCoachQuote(first, 'Primeira corrida'),
    };
    return {
      primaryDisplay: '01',
      stats,
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
    const stats = buildStatsFromRun(r);
    stats.extra = { ...(stats.extra ?? {}), coachQuote: firstRunCoachQuote(r, '5K') };
    return {
      primaryDisplay: '5K',
      stats,
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
    const stats = buildStatsFromRun(r);
    stats.extra = { ...(stats.extra ?? {}), coachQuote: firstRunCoachQuote(r, '10K') };
    return {
      primaryDisplay: '10K',
      stats,
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

const INDOOR_CHAMPION: BadgeDefinition = {
  badgeId: 'indoor_champion',
  category: 'first',
  title: 'Indoor Champion',
  subtitle: 'Corrida em esteira de 10 km ou mais',
  evaluate: ({ allRuns }) => {
    const r = allRuns.find(
      (x) => x.environment === 'indoor' && (x.distanceM ?? 0) >= 10000,
    );
    if (!r) return null;
    return {
      primaryDisplay: `${((r.distanceM ?? 0) / 1000).toFixed(1)}`,
      primaryUnit: 'km',
      stats: buildStatsFromRun(r),
      context: { runId: r.id },
      badgeChip: 'INDOOR CHAMPION',
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

const FIRST_ASSESSMENT: BadgeDefinition = {
  badgeId: 'first_assessment_run',
  category: 'first',
  title: 'Primeira Avaliação',
  subtitle: 'Ritmo medido em corrida de avaliação',
  description: 'Você correu a avaliação — o plano nasce do seu ritmo real, medido, não chutado.',
  evaluate: ({ allRuns }) => {
    const r = allRuns.find(
      (x) => typeof x.assessmentTargetKm === 'number' && x.assessmentTargetKm > 0,
    );
    if (!r) return null;
    const km = r.distanceM ? (r.distanceM / 1000).toFixed(1) : '?';
    const pace = r.avgPace ?? '—';
    const effort = r.assessmentResult?.effortLabel;
    const effortNote = effort === 'maximo' || effort === 'forte'
      ? ' Esforço alto detectado pela FC — o coach calibrou o pace base pelo sustentável.'
      : '';
    const stats = buildStatsFromRun(r);
    stats.extra = {
      ...(stats.extra ?? {}),
      ...(r.assessmentResult?.pctHrr != null ? { pctHrr: r.assessmentResult.pctHrr } : {}),
      ...(effort ? { effortLabel: effort } : {}),
      coachQuote:
        `Avaliação concluída: ${km}km a ${pace}/km.${effortNote} ` +
        'A partir daqui, o plano mede contra o seu ritmo REAL.',
    };
    return {
      primaryDisplay: pace,
      primaryUnit: '/km',
      stats,
      context: { runId: r.id },
      badgeChip: 'RITMO MEDIDO',
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
      // Span em dias: primeira run válida até a run que cruzou o target.
      const sorted = [...allRuns].sort(
        (a, b) => new Date(a.createdAt as string).getTime() -
                  new Date(b.createdAt as string).getTime(),
      );
      let acc = 0;
      let crossingRun = sorted[sorted.length - 1];
      for (const r of sorted) {
        acc += (r.distanceM ?? 0) / 1000;
        if (acc >= target) { crossingRun = r; break; }
      }
      const firstDate = sorted[0] ? new Date(sorted[0].createdAt as string) : null;
      const crossDate = crossingRun ? new Date(crossingRun.createdAt as string) : null;
      const spanDays = firstDate && crossDate
        ? Math.max(1, Math.round((crossDate.getTime() - firstDate.getTime()) / 86400000))
        : null;
      return {
        primaryDisplay: `${target}`,
        primaryUnit: 'km',
        stats: {
          distanceKm: Math.round(km * 10) / 10,
          extra: {
            target,
            runsTotal: allRuns.length,
            ...(spanDays !== null ? { spanDays } : {}),
            coachQuote:
              `${km.toFixed(0)}km em ${allRuns.length} corridas` +
              (spanDays !== null ? `, ao longo de ${spanDays} dias. ` : '. ') +
              `Cada quilômetro custou esforço real — não foi acaso.`,
          },
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
          extra: {
            streak,
            target,
            coachQuote:
              `${streak} dias seguidos correndo. ` +
              `Consistência é o ativo que mais valoriza com o tempo — você ` +
              `acabou de provar que tem.`,
          },
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
      // Extrai pace REAL inicial do user (primeira run válida com pace) +
      // delta em segundos pro template "antes → depois" no card.
      const sorted = [...allRuns].sort(
        (a, b) => new Date(a.createdAt as string).getTime() -
                  new Date(b.createdAt as string).getTime(),
      );
      const firstWithPace = sorted.find(x => paceToSeconds(x.avgPace) !== null);
      const firstPaceSec = firstWithPace ? paceToSeconds(firstWithPace.avgPace) : null;
      const prPaceSec = paceToSeconds(r.avgPace);
      const stats = buildStatsFromRun(r);
      if (firstPaceSec !== null && prPaceSec !== null) {
        stats.extra = {
          ...(stats.extra ?? {}),
          firstPace: firstWithPace!.avgPace as string,
          paceDeltaSec: prPaceSec - firstPaceSec,
          coachQuote: buildPaceCoachQuote(
            firstWithPace!.avgPace as string,
            r.avgPace as string,
            prPaceSec - firstPaceSec,
          ),
        };
      }
      return {
        primaryDisplay: r.avgPace ?? labelPace,
        primaryUnit: '/km',
        stats,
        context: { runId: r.id },
        badgeChip: label,
      };
    },
  };
}

/** Gera quote do coach baseada em dados reais: pace inicial vs pace do PR
 *  e o ganho em segundos por km. Sem fallback genérico. */
function buildPaceCoachQuote(firstPace: string, prPace: string, deltaSec: number): string {
  const gainAbs = Math.abs(deltaSec);
  if (deltaSec >= 0) {
    return `${firstPace}/km → ${prPace}/km. Pace estável é base; agora atacar o teto.`;
  }
  return `Você saiu de ${firstPace}/km para sub-${prPace}/km. ${gainAbs}s por km é ganho real de treino — não foi sorte.`;
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
    const start = new Date(weekStart);
    const end = new Date(start);
    end.setUTCDate(end.getUTCDate() + 7);
    const weekRuns = allRuns.filter((r) => {
      const d = new Date(r.createdAt as string);
      return d >= start && d < end;
    });
    const weekKm = totalKm(weekRuns);
    const durationS = weekRuns.reduce((s, r) => s + (r.durationS ?? 0), 0);
    // Barras verticais por dia da semana (km/dia). Cliente renderiza
    // _VerticalBars quando `dailyBars` está em extra.
    const dailyBars = Array(7).fill(0);
    const dailyLabels = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
    for (const r of weekRuns) {
      const d = new Date(r.createdAt as string);
      // dayOfWeek: 1=Mon..7=Sun, ajusta pra index 0..6
      const dow = d.getUTCDay(); // 0=Sun..6=Sat
      const idx = dow === 0 ? 6 : dow - 1;
      dailyBars[idx] += (r.distanceM ?? 0) / 1000;
    }
    const avgPaceSec = weekRuns
      .map(r => paceToSeconds(r.avgPace))
      .filter((x): x is number => x !== null);
    const avgPace = avgPaceSec.length > 0
      ? Math.round(avgPaceSec.reduce((a, b) => a + b, 0) / avgPaceSec.length)
      : null;
    const avgPaceLabel = avgPace !== null
      ? `${Math.floor(avgPace / 60)}:${(avgPace % 60).toString().padStart(2, '0')}`
      : '—';
    return {
      primaryDisplay: weekKm.toFixed(1),
      primaryUnit: 'km',
      stats: {
        weekKm: Math.round(weekKm * 10) / 10,
        distanceKm: Math.round(weekKm * 10) / 10,
        durationS,
        extra: {
          runsCount: weekRuns.length,
          weekStart,
          dailyBars: dailyBars.map(v => Math.round(v * 10) / 10),
          dailyLabels,
          barUnit: 'km',
          avgPaceLabel,
          coachQuote:
            `${weekRuns.length} corridas, ${weekKm.toFixed(1)}km e pace médio ${avgPaceLabel}/km na semana. ` +
            `Esse é o teu retrato semanal — métrica honesta pra próxima.`,
        },
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
    const durationS = monthRuns.reduce((s, r) => s + (r.durationS ?? 0), 0);
    // 4-5 barras semanais por semana ISO do mês
    const weeklyMap = new Map<number, number>();
    for (const r of monthRuns) {
      const d = new Date(r.createdAt as string);
      const week = getISOWeek(d);
      weeklyMap.set(week, (weeklyMap.get(week) ?? 0) + (r.distanceM ?? 0) / 1000);
    }
    const sortedWeeks = [...weeklyMap.entries()].sort((a, b) => a[0] - b[0]);
    const dailyBars = sortedWeeks.map(([_, km]) => Math.round(km * 10) / 10);
    const dailyLabels = sortedWeeks.map(([wk]) => `S${wk}`);
    const bestRun = monthRuns.reduce<Run | null>(
      (best, r) => (best == null || (r.distanceM ?? 0) > (best.distanceM ?? 0)) ? r : best,
      null,
    );
    return {
      primaryDisplay: monthKm.toFixed(1),
      primaryUnit: 'km',
      stats: {
        monthKm: Math.round(monthKm * 10) / 10,
        distanceKm: Math.round(monthKm * 10) / 10,
        durationS,
        extra: {
          runsCount: monthRuns.length,
          monthKey,
          dailyBars,
          dailyLabels,
          barUnit: 'km',
          ...(bestRun ? { bestRunKm: Math.round((bestRun.distanceM ?? 0) / 100) / 10 } : {}),
          coachQuote:
            `${monthRuns.length} corridas e ${monthKm.toFixed(1)}km no mês. ` +
            `Mensal mostra tendência — agora dá pra ver se a base tá subindo.`,
        },
      },
      context: { monthKey },
      badgeChip: monthKey,
    };
  },
};

/** ISO week number (1-53) — usado pro agrupamento semanal do MONTHLY_REPORT. */
function getISOWeek(d: Date): number {
  const target = new Date(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
  const dayNr = (target.getDay() + 6) % 7;
  target.setDate(target.getDate() - dayNr + 3);
  const firstThursday = target.valueOf();
  target.setMonth(0, 1);
  if (target.getDay() !== 4) {
    target.setMonth(0, 1 + ((4 - target.getDay()) + 7) % 7);
  }
  return 1 + Math.ceil((firstThursday - target.valueOf()) / 604800000);
}

// ── Registry ────────────────────────────────────────────────────────────

export const BADGE_DEFINITIONS: BadgeDefinition[] = [
  // Primeiras vezes
  FIRST_RUN,
  FIRST_ASSESSMENT,
  FIRST_PLAN_RUN,
  FIRST_DAWN_RUN,
  FIRST_NIGHT_RUN,
  FIRST_MIDNIGHT_RUN,
  FIRST_LONG_RUN,
  FIRST_5K,
  FIRST_10K,
  FIRST_HALF_MARATHON,
  FIRST_MARATHON,
  INDOOR_CHAMPION,
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
