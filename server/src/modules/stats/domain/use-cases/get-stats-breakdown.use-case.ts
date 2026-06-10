import { Run } from '@modules/runs/domain/run.entity';
import { RunRepository } from '@modules/runs/domain/run.repository';
import { Plan, effectivePlanWeeks } from '@modules/plans/domain/plan.entity';
import { PlanRepository } from '@modules/plans/domain/plan.repository';
import { StatsPeriod } from '../stats-aggregate.entity';
import {
  StatsBreakdown,
  BreakdownStats,
  VolumeBucket,
  PaceBucket,
} from '../stats-breakdown.entity';

interface Bucket {
  label: string;
  start: Date; // inclusive (local midnight)
  end: Date; // exclusive
}

/**
 * Corridas curtas (<30s) ou sem deslocamento (<100m) são ignoradas pelas
 * estatísticas. User abriu a tela de corrida e fechou rápido sem mover,
 * testou o botão de iniciar, ou perdeu sinal de GPS — esse "ruído"
 * distorcia o pace médio do período (pace de uma corrida de 5s com 2m é
 * absurdo) e inflava o total de corridas em treino/dados.
 *
 * Os runs com <30s/<100m continuam armazenados; só ficam fora dos agregados
 * mostrados em /stats/breakdown (Treino > Dados) e /stats/aggregate
 * (Home > Performance). Espelhado em get-stats-aggregate.use-case.ts.
 */
const MIN_VALID_DURATION_S = 30;
const MIN_VALID_DISTANCE_M = 100;

// Curva de níveis — espelha app/lib/core/gamification/levels.dart.
const LEVELS: { threshold: number; name: string }[] = [
  { threshold: 0, name: 'Iniciante' },
  { threshold: 200, name: 'Aprendiz' },
  { threshold: 500, name: 'Corredor' },
  { threshold: 1000, name: 'Atleta' },
  { threshold: 2000, name: 'Veterano' },
  { threshold: 4000, name: 'Mestre' },
  { threshold: 8000, name: 'Lenda' },
];

const MONTHS_PT = ['JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'];
const DOW_PT = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];

export class GetStatsBreakdownUseCase {
  constructor(
    private readonly runs: RunRepository,
    private readonly plans: PlanRepository,
  ) {}

  async execute(
    userId: string,
    period: StatsPeriod,
    /** Offset em minutos da TZ do user vs UTC (Dart: DateTime.now().timeZoneOffset.inMinutes;
     *  POSITIVO ao leste, negativo ao oeste. BRT = -180). Sem isso o
     *  server (Cloud Run = UTC) calculava "esta semana" usando meia-noite
     *  UTC e cortava runs do user feitas tarde da noite local (que ficam
     *  no dia UTC seguinte ou anterior). Default 0 = UTC (backwards-compat). */
    tzOffsetMin: number = 0,
  ): Promise<StatsBreakdown> {
    const now = new Date();
    const buckets = buildBuckets(period, now, tzOffsetMin);
    const windowStart = buckets[0]!.start;
    const windowEnd = now;

    const [periodRunsRaw, allRuns, plans] = await Promise.all([
      this.runs.findByDateRange(userId, windowStart, windowEnd),
      this.runs.findByUser(userId, 1000),
      this.plans.listByUser(userId),
    ]);

    // Filtra ruído: corridas curtas demais ou sem deslocamento sujam o pace
    // médio e inflam o contador de corridas. Aplicado em períodos E lifetime
    // — XP/level/streak também ignoram esses runs.
    const isValidRun = (r: Run): boolean =>
      (r.durationS ?? 0) >= MIN_VALID_DURATION_S &&
      (r.distanceM ?? 0) >= MIN_VALID_DISTANCE_M;
    const periodRuns = periodRunsRaw.filter(isValidRun);
    const completedLifetime = allRuns.runs.filter(
      (r) => r.status === 'completed' && isValidRun(r),
    );

    const stats = this.buildStats(periodRuns, completedLifetime);
    const planned = expandPlans(plans);
    const { volume, pace } = this.buildSeries(buckets, periodRuns, planned, plans);

    // TF 77: log estendido pra debug do bug volume/pace planejado errado.
    try {
      const { logger } = await import('@shared/logger/logger');
      const planSummary = plans.map((p) => {
        const weeks = (p.adjustedWeeks ?? p.weeks ?? []) as Array<{
          weekNumber: number;
          sessions?: Array<{ dayOfWeek: number; distanceKm?: number; targetPace?: string }>;
        }>;
        return {
          planId: p.id,
          startDate: p.startDate ?? p.createdAt,
          weeksCount: weeks.length,
          weeks: weeks.map((w) => ({
            wn: w.weekNumber,
            sessions: (w.sessions ?? []).map((s) =>
              `dow${s.dayOfWeek}=${s.distanceKm ?? 0}km`,
            ).join('|'),
          })),
        };
      });
      const expandedSummary = planned.map((m, i) => {
        const entries = Array.from(m.entries()).map(([k, v]) => `${k}:${v.km}km`);
        return { planIdx: i, days: entries };
      });
      logger.info('stats.breakdown.deep_dump', {
        uid: userId,
        period,
        tzOffsetMin,
        buckets: buckets.map((b) => ({
          label: b.label,
          start: b.start.toISOString(),
          end: b.end.toISOString(),
        })),
        plans: planSummary,
        expanded: expandedSummary,
        volume,
      });
    } catch (_) {/* ignore */}

    return { period, stats, volume, pace };
  }

  private buildStats(periodRuns: Run[], lifetime: Run[]): BreakdownStats {
    const runs = periodRuns.length;
    const totalDistanceM = periodRuns.reduce((s, r) => s + (r.distanceM || 0), 0);
    const totalDistanceKm = round1(totalDistanceM / 1000);
    const totalDurationS = periodRuns.reduce((s, r) => s + (r.durationS || 0), 0);
    const calories = Math.round(periodRuns.reduce((s, r) => s + (r.calories || 0), 0));
    const totalXp = periodRuns.reduce((s, r) => s + (r.xpEarned || 0), 0);

    // Pace médio = duração total / distância total (weighted por distância).
    // Antes era média aritmética dos paces de cada run, que distorcia o
    // valor quando havia runs de tamanhos muito diferentes.
    const avgPaceSec = totalDistanceM > 0 && totalDurationS > 0
      ? Math.round((totalDurationS / totalDistanceM) * 1000)
      : null;

    const bpms = periodRuns.map((r) => r.avgBpm).filter((b): b is number => typeof b === 'number');
    const avgBpm = bpms.length ? Math.round(avg(bpms)) : null;
    const maxBpms = periodRuns.map((r) => r.maxBpm).filter((b): b is number => typeof b === 'number');
    const maxBpm = maxBpms.length ? Math.max(...maxBpms) : null;

    // Lifetime: nível (por XP total) e streak (dias consecutivos).
    const lifetimeXp = lifetime.reduce((s, r) => s + (r.xpEarned || 0), 0);
    const { level, levelName } = resolveLevel(lifetimeXp);
    const streak = computeStreak(lifetime);

    return {
      runs,
      totalDistanceKm,
      avgDistanceKm: runs > 0 ? round1(totalDistanceKm / runs) : 0,
      totalDurationS,
      avgPace: avgPaceSec !== null ? secToPace(avgPaceSec) : null,
      calories,
      level,
      levelName,
      avgBpm,
      maxBpm,
      streak,
      totalXp,
    };
  }

  private buildSeries(
    buckets: Bucket[],
    periodRuns: Run[],
    planned: Map<string, { km: number; paces: number[] }>[],
    plans: Plan[],
  ): { volume: VolumeBucket[]; pace: PaceBucket[] } {
    const volume: VolumeBucket[] = [];
    const pace: PaceBucket[] = [];

    for (const b of buckets) {
      // Realizado: runs no range do bucket.
      const inBucket = periodRuns.filter((r) => {
        const d = new Date(r.createdAt);
        return d >= b.start && d < b.end;
      });
      const bucketDistM = inBucket.reduce((s, r) => s + (r.distanceM || 0), 0);
      const bucketDurationS = inBucket.reduce((s, r) => s + (r.durationS || 0), 0);
      const realizedKm = round1(bucketDistM / 1000);
      // Pace médio do bucket = duração total / distância total (weighted),
      // mesma correção do buildStats — média aritmética dos avgPace de cada
      // run subvaloriza/supervaloriza runs por igual independente do peso.
      const realizedPaceSec = bucketDistM > 0 && bucketDurationS > 0
        ? Math.round((bucketDurationS / bucketDistM) * 1000)
        : null;

      // Planejado: itera cada dia do bucket, pega o plano ativo naquele dia.
      //
      // TF 77 F6 (bug 2): `addDays(d, 1)` usava `new Date(y, m, d+1)` que
      // construía meia-noite local UTC, perdendo o offset BRT. Resultado:
      // bucket SEG (08/jun 03:00 UTC → 09/jun 03:00 UTC) iterava d=08/jun
      // 03:00 → 09/jun 00:00 → ambos dentro do range, e dateKey do segundo
      // retornava "2026-06-09" → bucket pegava planejado do dia seguinte.
      // Fix: avança +24h preservando offset; dateKey usa getUTCDate (mesmo
      // truque local-as-UTC dos buckets).
      let plannedKm = 0;
      const plannedPaceSecs: number[] = [];
      for (let d = new Date(b.start); d < b.end; d = new Date(d.getTime() + 86400000)) {
        const planIdx = activePlanIndex(plans, d);
        if (planIdx < 0) continue;
        const day = planned[planIdx]!.get(dateKeyUtc(d));
        if (!day) continue;
        plannedKm += day.km;
        plannedPaceSecs.push(...day.paces);
      }

      volume.push({ label: b.label, plannedKm: round1(plannedKm), realizedKm });
      pace.push({
        label: b.label,
        // Planejado continua média simples — os paces vêm da config do
        // plano (alvo por sessão), não de execução real, então peso por
        // distância não faz sentido aqui.
        projectedPaceSec: plannedPaceSecs.length ? Math.round(avg(plannedPaceSecs)) : null,
        avgPaceSec: realizedPaceSec,
      });
    }

    return { volume, pace };
  }
}

// ── Buckets ──────────────────────────────────────────────────────────────────

function buildBuckets(period: StatsPeriod, now: Date, tzOffsetMin: number): Bucket[] {
  // Trabalha em "local-as-UTC": convertemos `now` UTC pra um Date que
  // *parece* meia-noite local quando lido como UTC. Todas as funções de
  // bucket usam getUTC* nesse Date. No final, voltamos pra UTC real
  // subtraindo o offset. Sem essa gambiarra, getDate/getMonth nativos
  // tentariam aplicar o TZ do processo (Cloud Run = UTC).
  const offsetMs = tzOffsetMin * 60 * 1000;
  const localNow = new Date(now.getTime() + offsetMs);
  const toUtc = (localDate: Date): Date => new Date(localDate.getTime() - offsetMs);

  if (period === 'week') {
    const monday = startOfWeekMondayLocal(localNow);
    return Array.from({ length: 7 }, (_, i) => {
      const startLocal = addDaysUtc(monday, i);
      const endLocal = addDaysUtc(monday, i + 1);
      return { label: DOW_PT[i]!, start: toUtc(startLocal), end: toUtc(endLocal) };
    });
  }
  if (period === 'month') {
    const y = localNow.getUTCFullYear();
    const m = localNow.getUTCMonth();
    const monthStartLocal = new Date(Date.UTC(y, m, 1));
    const nextMonthLocal = new Date(Date.UTC(y, m + 1, 1));
    const buckets: Bucket[] = [];
    let wk = 1;
    for (let day = 1; ; day += 7, wk++) {
      const startLocal = new Date(Date.UTC(y, m, day));
      if (startLocal >= nextMonthLocal) break;
      let endLocal = new Date(Date.UTC(y, m, day + 7));
      if (endLocal > nextMonthLocal) endLocal = nextMonthLocal;
      buckets.push({ label: `S${wk}`, start: toUtc(startLocal), end: toUtc(endLocal) });
    }
    void monthStartLocal;
    return buckets;
  }
  // threeMonths: mês atual + 2 anteriores. Cada bucket cobre o mês INTEIRO
  // (01 a 1º do próximo) — usuário compara plano vs executado no mês todo.
  //
  // TF 77 F6 (fix 2): removido cap em today+1 — limitava JUN ao 10/06 em
  // vez do mês inteiro, e o usuário via planejado de só ~10 dias contra o
  // plano que cobria 30. Como agora o iterator preserva offset e dateKeyUtc
  // recorta certo dia-a-dia, não há risco de "vazar" sessões do mês seguinte.
  const buckets: Bucket[] = [];
  const y = localNow.getUTCFullYear();
  const m = localNow.getUTCMonth();
  for (let i = 2; i >= 0; i--) {
    const startLocal = new Date(Date.UTC(y, m - i, 1));
    const endLocal = new Date(Date.UTC(y, m - i + 1, 1));
    buckets.push({
      label: MONTHS_PT[startLocal.getUTCMonth()]!,
      start: toUtc(startLocal),
      end: toUtc(endLocal),
    });
  }
  return buckets;
}

function startOfWeekMondayLocal(d: Date): Date {
  const date = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const dow = date.getUTCDay() === 0 ? 7 : date.getUTCDay(); // Mon=1..Sun=7
  return addDaysUtc(date, -(dow - 1));
}

function addDaysUtc(d: Date, n: number): Date {
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() + n));
}

// ── Plano (planejado) ──────────────────────────────────────────────────────

/** Expande cada plano num mapa dateKey → { km, paces[] } a partir das sessões.
 *
 *  TF 77 F6: bug pre-77 alocava sessões antes do startDate quando o plano não
 *  começa numa segunda. Ex: plano começa qua, sessão na seg → offset=1-3=-2,
 *  jogava a sessão num dia ANTES de startDate (não somava em nenhum bucket
 *  válido + sumia da semana atual + aparecia na semana anterior).
 *
 *  Correção: ancoramos o plano na SEGUNDA da semana de startDate (anterior
 *  ou igual). Cada (weekNumber, dayOfWeek) mapeia exatamente pra uma data
 *  calendário. Sessões antes de startDate são puladas. */
function expandPlans(plans: Plan[]): Map<string, { km: number; paces: number[] }>[] {
  return plans.map((plan) => {
    const map = new Map<string, { km: number; paces: number[] }>();
    const startStr = (plan.startDate ?? plan.createdAt).slice(0, 10);
    const start = parseLocalDate(startStr);
    const startWeekday = start.getDay() === 0 ? 7 : start.getDay(); // 1=seg..7=dom
    // Segunda da semana em que startDate está (ou o próprio startDate se for seg).
    const mondayOfWeek1 = addDays(start, -(startWeekday - 1));
    for (const week of effectivePlanWeeks(plan)) {
      for (const s of week.sessions ?? []) {
        const dow = s.dayOfWeek; // 1=seg..7=dom
        const offsetFromMonday = (week.weekNumber - 1) * 7 + (dow - 1);
        const sessionDate = addDays(mondayOfWeek1, offsetFromMonday);
        // Pula sessões antes do startDate (semana 1 incompleta quando plano
        // não começa na segunda).
        if (sessionDate < start) continue;
        const key = dateKey(sessionDate);
        const entry = map.get(key) ?? { km: 0, paces: [] };
        entry.km += s.distanceKm || 0;
        const ps = paceToSec(s.targetPace);
        if (ps !== null) entry.paces.push(ps);
        map.set(key, entry);
      }
    }
    return map;
  });
}

/** Índice do plano ativo numa data: o último (maior startDate) cujo início é
 *  <= a data. Fallback: o primeiro plano. -1 se não há planos. */
function activePlanIndex(plans: Plan[], day: Date): number {
  if (plans.length === 0) return -1;
  let active = 0;
  for (let i = 0; i < plans.length; i++) {
    const startStr = (plans[i]!.startDate ?? plans[i]!.createdAt).slice(0, 10);
    if (parseLocalDate(startStr).getTime() <= day.getTime()) active = i;
  }
  return active;
}

// ── Stats lifetime ─────────────────────────────────────────────────────────

function resolveLevel(totalXp: number): { level: number; levelName: string } {
  const xp = Math.max(0, totalXp);
  for (let i = LEVELS.length - 1; i >= 0; i--) {
    if (xp >= LEVELS[i]!.threshold) {
      return { level: i + 1, levelName: LEVELS[i]!.name };
    }
  }
  return { level: 1, levelName: 'Iniciante' };
}

/** Dias consecutivos com corrida completa terminando em hoje ou ontem. */
function computeStreak(lifetime: Run[]): number {
  const days = new Set<string>();
  for (const r of lifetime) {
    const d = new Date(r.createdAt);
    days.add(dateKey(new Date(d.getFullYear(), d.getMonth(), d.getDate())));
  }
  if (days.size === 0) return 0;
  const today = new Date();
  const t0 = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  // Se não correu hoje, permite começar de ontem.
  let cursor = days.has(dateKey(t0)) ? t0 : addDays(t0, -1);
  let streak = 0;
  while (days.has(dateKey(cursor))) {
    streak++;
    cursor = addDays(cursor, -1);
  }
  return streak;
}

// ── Util ─────────────────────────────────────────────────────────────────────

function addDays(d: Date, n: number): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
}

function dateKey(d: Date): string {
  return `${d.getFullYear()}-${(d.getMonth() + 1).toString().padStart(2, '0')}-${d
    .getDate()
    .toString()
    .padStart(2, '0')}`;
}

/** Igual a `dateKey` mas usa componentes UTC. Necessário pra iterar buckets
 *  em local-as-UTC (start/end já carregam o offset) sem deixar a TZ do
 *  processo (UTC no Cloud Run) interferir no recorte dia-a-dia. */
function dateKeyUtc(d: Date): string {
  return `${d.getUTCFullYear()}-${(d.getUTCMonth() + 1).toString().padStart(2, '0')}-${d
    .getUTCDate()
    .toString()
    .padStart(2, '0')}`;
}

function parseLocalDate(yyyymmdd: string): Date {
  const [y, m, d] = yyyymmdd.split('-').map(Number);
  return new Date(y ?? 1970, (m ?? 1) - 1, d ?? 1);
}

function paceToSec(pace: string | undefined): number | null {
  if (!pace) return null;
  const m = pace.match(/^(\d+):(\d{1,2})$/);
  if (!m) return null;
  return Number(m[1]) * 60 + Number(m[2]);
}

function secToPace(sec: number): string {
  const m = Math.floor(sec / 60);
  const s = Math.round(sec % 60);
  return `${m}:${s.toString().padStart(2, '0')}`;
}

function avg(nums: number[]): number {
  return nums.reduce((a, b) => a + b, 0) / nums.length;
}

function round1(n: number): number {
  return Math.round(n * 10) / 10;
}
