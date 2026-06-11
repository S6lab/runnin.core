import { Run } from '@modules/runs/domain/run.entity';
import { RunRepository } from '@modules/runs/domain/run.repository';
import { UserRepository } from '@modules/users/domain/user.repository';
import { UserProfile } from '@modules/users/domain/user.entity';
import {
  computeKarvonenZones,
  classifyKarvonenZone,
} from '@modules/health/domain/zone.entity';
import {
  StatsAggregate,
  StatsPeriod,
  StatsTotals,
  StatsAverages,
  StatsDeltas,
  WeeklyVolumeEntry,
  TrendEntry,
} from '../stats-aggregate.entity';

/**
 * Corridas curtas (<30s) ou sem deslocamento (<100m) são ruído (user tocou
 * INICIAR e fechou, ou GPS perdeu sinal). Filtra antes de agregar pra não
 * sujar pace trend / averages / deltas da Home > Performance. Espelhado
 * em get-stats-breakdown.use-case.ts.
 * `status === 'completed'` espelha o filtro do client (history_page) —
 * antes runs abandonadas entravam nos deltas mas não nos valores exibidos.
 */
const MIN_VALID_DURATION_S = 30;
const MIN_VALID_DISTANCE_M = 100;
const isValidRun = (r: Run): boolean =>
  r.status === 'completed' &&
  (r.durationS ?? 0) >= MIN_VALID_DURATION_S &&
  (r.distanceM ?? 0) >= MIN_VALID_DISTANCE_M;

export class GetStatsAggregateUseCase {
  constructor(
    private readonly runs: RunRepository,
    private readonly userRepo: UserRepository,
  ) {}

  async execute(
    userId: string,
    period: StatsPeriod,
    tzOffsetMin: number = 0,
  ): Promise<StatsAggregate> {
    // Janela CIVIL alinhada com o client (history_page._periodRange):
    // semana = segunda→agora, mês = 1º→agora, trimestre = 3 meses civis.
    // Antes era rolling (últimos N dias a partir de agora) — o valor da
    // tile (janela civil, client-side) e o delta (rolling, server-side)
    // falavam de períodos diferentes e a tendência parecia "errada".
    const now = new Date();
    const { start, prevStart } = civilWindows(period, now, tzOffsetMin);

    const [currentRaw, previousRaw, user] = await Promise.all([
      this.runs.findByDateRange(userId, start, now),
      this.runs.findByDateRange(userId, prevStart, start),
      this.userRepo.findById(userId),
    ]);
    const current = currentRaw.filter(isValidRun);
    const previous = previousRaw.filter(isValidRun);

    // Cumulativos (volume/corridas) comparam pro-rata: só a fatia do
    // período anterior com o MESMO tempo decorrido do atual. Sem isso,
    // numa quarta-feira o volume da semana parcial perdia sempre pra
    // semana anterior completa e o delta vivia negativo.
    const elapsedMs = now.getTime() - start.getTime();
    const prevCut = new Date(
      Math.min(prevStart.getTime() + elapsedMs, start.getTime()),
    );
    const previousProRata = previous.filter(
      (r) => new Date(r.createdAt) < prevCut,
    );

    return {
      totals: this.totals(current),
      averages: this.averages(current),
      deltas: this.deltas(current, previous, previousProRata),
      zoneDistribution: this.zones(current, user),
      weeklyVolume: this.weeklyVolume(current, start, now),
      paceTrend: this.paceTrend(current),
      bpmTrend: this.bpmTrend(current),
    };
  }

  private totals(runs: Run[]): StatsTotals {
    return {
      count: runs.length,
      totalDistanceM: runs.reduce((s, r) => s + (r.distanceM || 0), 0),
      totalDurationS: runs.reduce((s, r) => s + (r.durationS || 0), 0),
      totalCalories: runs.reduce((s, r) => s + (r.calories || 0), 0),
      totalXp: runs.reduce((s, r) => s + (r.xpEarned || 0), 0),
    };
  }

  private averages(runs: Run[]): StatsAverages {
    if (runs.length === 0) {
      return { avgPaceMinKm: null, avgBpm: null, maxBpm: null, avgDistanceKmPerRun: 0 };
    }
    // Pace médio = duração total / distância total (weighted por distância).
    // Antes era média aritmética dos paces individuais, que distorcia o
    // agregado quando havia runs de tamanhos muito diferentes — uma run
    // curta lenta puxava o pace pra cima sem contribuir muito pro volume.
    const totalDistM = runs.reduce((s, r) => s + (r.distanceM || 0), 0);
    const totalDurationS = runs.reduce((s, r) => s + (r.durationS || 0), 0);
    const avgPaceVal = totalDistM > 0 && totalDurationS > 0
      ? (totalDurationS / totalDistM) * 1000 / 60  // s/m → min/km
      : null;
    const bpms = runs.map(r => r.avgBpm).filter((b): b is number => typeof b === 'number');
    const avgBpm = bpms.length > 0 ? Math.round(bpms.reduce((a, b) => a + b, 0) / bpms.length) : null;
    const maxBpms = runs.map(r => r.maxBpm).filter((b): b is number => typeof b === 'number');
    const maxBpm = maxBpms.length > 0 ? Math.max(...maxBpms) : null;
    const totalDistKm = totalDistM / 1000;
    return {
      avgPaceMinKm: avgPaceVal !== null ? this.minToPace(avgPaceVal) : null,
      avgBpm,
      maxBpm,
      avgDistanceKmPerRun: runs.length > 0 ? totalDistKm / runs.length : 0,
    };
  }

  /// Deltas vs período anterior. Pace/BPM (médias) comparam contra o
  /// período anterior INTEIRO; volume/corridas (cumulativos) contra a
  /// fatia pro-rata [previousProRata] — mesmo tempo decorrido do atual.
  private deltas(
    current: Run[],
    previous: Run[],
    previousProRata: Run[],
  ): StatsDeltas {
    // Pace numérico direto dos totais — antes parseava a string formatada
    // ("5:30"), perdendo precisão de arredondamento no delta.
    const paceMin = (runs: Run[]): number | null => {
      const dist = runs.reduce((s, r) => s + (r.distanceM || 0), 0);
      const dur = runs.reduce((s, r) => s + (r.durationS || 0), 0);
      return dist > 0 && dur > 0 ? (dur / dist) * 1000 / 60 : null;
    };
    const currPace = paceMin(current);
    const prevPace = paceMin(previous);
    const curr = this.averages(current);
    const prev = this.averages(previous);
    const currVol = current.reduce((s, r) => s + (r.distanceM || 0), 0);
    const prevVol = previousProRata.reduce((s, r) => s + (r.distanceM || 0), 0);

    const pacePctVsPrev = currPace !== null && prevPace !== null
      ? this.pctChange(prevPace, currPace)
      : null;
    const volumePctVsPrev = prevVol > 0 ? this.pctChange(prevVol, currVol) : null;
    const bpmDeltaBpm = curr.avgBpm !== null && prev.avgBpm !== null ? curr.avgBpm - prev.avgBpm : null;

    return {
      pacePctVsPrev,
      volumePctVsPrev,
      bpmDeltaBpm,
      runsCountDelta: current.length - previousProRata.length,
    };
  }

  private zones(runs: Run[], user: UserProfile | null): number[] {
    // 5 zonas Karvonen baseadas em maxBpm/restingBpm do profile. Antes era
    // tabela hardcoded (Z1<120, Z2 120-140…); usuários com FC máx diferente
    // de ~190 ficavam sem zonas relevantes. Agora unificado com a
    // página /zonas (mesmo helper de health/domain/zone.entity).
    const zones = this.zonesFor(user);
    if (!zones) {
      // Sem dados pra calcular zonas → distribuição zerada. UI deve
      // checar a flag `zonesAvailable` e esconder o gráfico (TODO entity).
      return [0, 0, 0, 0, 0];
    }
    const counts = [0, 0, 0, 0, 0];
    for (const r of runs) {
      const bpm = r.avgBpm;
      if (typeof bpm !== 'number') continue;
      const idx = classifyKarvonenZone(bpm, zones);
      if (idx !== null) counts[idx]!++;
    }
    const total = counts.reduce((a, b) => a + b, 0);
    if (total === 0) return [0, 0, 0, 0, 0];
    return counts.map((c) => c / total);
  }

  /** Resolve maxBpm/restingBpm pro perfil, com fallback Tanaka quando só
   *  birthDate está presente. Retorna null se não der pra estimar. */
  private zonesFor(user: UserProfile | null): { min: number; max: number }[] | null {
    if (!user) return null;
    const maxBpm = user.maxBpm ?? this.tanakaMaxBpm(user.birthDate);
    if (!maxBpm) return null;
    const restingBpm = user.restingBpm ?? 60; // default razoável quando ausente
    return computeKarvonenZones(maxBpm, restingBpm);
  }

  /** Tanaka 2001: 208 − 0.7×idade. Mais preciso pra adultos do que 220−idade. */
  private tanakaMaxBpm(birthDate?: string): number | null {
    if (!birthDate) return null;
    const dob = new Date(birthDate);
    if (Number.isNaN(dob.getTime())) return null;
    const now = new Date();
    const age = now.getFullYear() - dob.getFullYear() -
      (now < new Date(now.getFullYear(), dob.getMonth(), dob.getDate()) ? 1 : 0);
    if (age <= 0 || age > 120) return null;
    return Math.round(208 - 0.7 * age);
  }

  private weeklyVolume(runs: Run[], from: Date, to: Date): WeeklyVolumeEntry[] {
    const weeks: WeeklyVolumeEntry[] = [];
    const cursor = new Date(from);
    while (cursor < to) {
      const weekStart = new Date(cursor);
      const weekEnd = new Date(cursor.getTime() + 7 * 24 * 60 * 60 * 1000);
      const inWeek = runs.filter(r => {
        const d = new Date(r.createdAt);
        return d >= weekStart && d < weekEnd;
      });
      const executedKm = inWeek.reduce((s, r) => s + (r.distanceM || 0), 0) / 1000;
      weeks.push({
        weekLabel: weekStart.toISOString().slice(5, 10), // MM-DD
        plannedKm: 0, // sem integração com plano por enquanto
        executedKm: Math.round(executedKm * 10) / 10,
      });
      cursor.setTime(weekEnd.getTime());
    }
    return weeks;
  }

  private paceTrend(runs: Run[]): TrendEntry[] {
    return runs.map(r => ({
      date: r.createdAt.slice(0, 10),
      avgPaceMinKm: r.avgPace ?? null,
      avgBpm: null,
    }));
  }

  private bpmTrend(runs: Run[]): TrendEntry[] {
    return runs.map(r => ({
      date: r.createdAt.slice(0, 10),
      avgPaceMinKm: null,
      avgBpm: r.avgBpm ?? null,
    }));
  }

  private paceToMin(pace: string | undefined): number | null {
    if (!pace) return null;
    const [min, sec] = pace.split(':').map(Number);
    if (typeof min !== 'number' || typeof sec !== 'number' || isNaN(min) || isNaN(sec)) return null;
    return min + sec / 60;
  }

  private minToPace(min: number): string {
    let m = Math.floor(min);
    let s = Math.round((min - m) * 60);
    // Carry: 5.999 min arredondava pra "5:60" em vez de "6:00".
    if (s === 60) {
      m += 1;
      s = 0;
    }
    return `${m}:${s.toString().padStart(2, '0')}`;
  }

  private pctChange(prev: number, curr: number): number {
    if (prev === 0) return 0;
    return Math.round(((curr - prev) / prev) * 100);
  }
}

/**
 * Janelas civis do período na timezone do CLIENT (tzOffsetMin, ex: BRT
 * = -180), alinhadas 1:1 com history_page._periodRange do app:
 *   week        → segunda da semana corrente; anterior = segunda anterior
 *   month       → 1º do mês corrente; anterior = 1º do mês anterior
 *   threeMonths → 1º de (mês-2); anterior = 1º de (mês-5)
 * Mesma técnica local-as-UTC do buildBuckets (get-stats-breakdown).
 */
function civilWindows(
  period: StatsPeriod,
  now: Date,
  tzOffsetMin: number,
): { start: Date; prevStart: Date } {
  const offsetMs = tzOffsetMin * 60 * 1000;
  const localNow = new Date(now.getTime() + offsetMs);
  const toUtc = (d: Date): Date => new Date(d.getTime() - offsetMs);
  const y = localNow.getUTCFullYear();
  const m = localNow.getUTCMonth();

  if (period === 'week') {
    const day = new Date(Date.UTC(y, m, localNow.getUTCDate()));
    const dow = day.getUTCDay() === 0 ? 7 : day.getUTCDay(); // Mon=1..Sun=7
    const monday = new Date(
      Date.UTC(y, m, localNow.getUTCDate() - (dow - 1)),
    );
    const prevMonday = new Date(
      Date.UTC(
        monday.getUTCFullYear(),
        monday.getUTCMonth(),
        monday.getUTCDate() - 7,
      ),
    );
    return { start: toUtc(monday), prevStart: toUtc(prevMonday) };
  }
  if (period === 'month') {
    return {
      start: toUtc(new Date(Date.UTC(y, m, 1))),
      prevStart: toUtc(new Date(Date.UTC(y, m - 1, 1))),
    };
  }
  // threeMonths
  return {
    start: toUtc(new Date(Date.UTC(y, m - 2, 1))),
    prevStart: toUtc(new Date(Date.UTC(y, m - 5, 1))),
  };
}
