import { Run } from '@modules/runs/domain/run.entity';
import { RunRepository } from '@modules/runs/domain/run.repository';
import {
  StatsAggregate,
  StatsPeriod,
  StatsTotals,
  StatsAverages,
  StatsDeltas,
  WeeklyVolumeEntry,
  TrendEntry,
} from '../stats-aggregate.entity';

const PERIOD_DAYS: Record<StatsPeriod, number> = {
  week: 7,
  month: 30,
  threeMonths: 90,
};

/**
 * Corridas curtas (<30s) ou sem deslocamento (<100m) são ruído (user tocou
 * INICIAR e fechou, ou GPS perdeu sinal). Filtra antes de agregar pra não
 * sujar pace trend / averages / deltas da Home > Performance. Espelhado
 * em get-stats-breakdown.use-case.ts.
 */
const MIN_VALID_DURATION_S = 30;
const MIN_VALID_DISTANCE_M = 100;
const isValidRun = (r: Run): boolean =>
  (r.durationS ?? 0) >= MIN_VALID_DURATION_S &&
  (r.distanceM ?? 0) >= MIN_VALID_DISTANCE_M;

export class GetStatsAggregateUseCase {
  constructor(private readonly runs: RunRepository) {}

  async execute(userId: string, period: StatsPeriod): Promise<StatsAggregate> {
    const days = PERIOD_DAYS[period];
    const now = new Date();
    const from = new Date(now.getTime() - days * 24 * 60 * 60 * 1000);
    const prevFrom = new Date(from.getTime() - days * 24 * 60 * 60 * 1000);

    const [currentRaw, previousRaw] = await Promise.all([
      this.runs.findByDateRange(userId, from, now),
      this.runs.findByDateRange(userId, prevFrom, from),
    ]);
    const current = currentRaw.filter(isValidRun);
    const previous = previousRaw.filter(isValidRun);

    return {
      totals: this.totals(current),
      averages: this.averages(current),
      deltas: this.deltas(current, previous),
      zoneDistribution: this.zones(current),
      weeklyVolume: this.weeklyVolume(current, from, now),
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

  private deltas(current: Run[], previous: Run[]): StatsDeltas {
    const curr = this.averages(current);
    const prev = this.averages(previous);
    const currVol = current.reduce((s, r) => s + (r.distanceM || 0), 0);
    const prevVol = previous.reduce((s, r) => s + (r.distanceM || 0), 0);

    const pacePctVsPrev = curr.avgPaceMinKm && prev.avgPaceMinKm
      ? this.pctChange(this.paceToMin(prev.avgPaceMinKm)!, this.paceToMin(curr.avgPaceMinKm)!)
      : null;
    const volumePctVsPrev = prevVol > 0 ? this.pctChange(prevVol, currVol) : null;
    const bpmDeltaBpm = curr.avgBpm !== null && prev.avgBpm !== null ? curr.avgBpm - prev.avgBpm : null;

    return {
      pacePctVsPrev,
      volumePctVsPrev,
      bpmDeltaBpm,
      runsCountDelta: current.length - previous.length,
    };
  }

  private zones(runs: Run[]): number[] {
    // 5 zonas baseadas em avgBpm (Z1<120, Z2 120-140, Z3 140-160, Z4 160-175, Z5 >175).
    // Sem KmSplit BPM real ainda; placeholder por run.avgBpm. Soma = 1.0 (ou zeros se vazio).
    const counts = [0, 0, 0, 0, 0];
    for (const r of runs) {
      const bpm = r.avgBpm;
      if (typeof bpm !== 'number') continue;
      if (bpm < 120) counts[0]!++;
      else if (bpm < 140) counts[1]!++;
      else if (bpm < 160) counts[2]!++;
      else if (bpm < 175) counts[3]!++;
      else counts[4]!++;
    }
    const total = counts.reduce((a, b) => a + b, 0);
    if (total === 0) return [0, 0, 0, 0, 0];
    return counts.map(c => c / total);
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
    const m = Math.floor(min);
    const s = Math.round((min - m) * 60);
    return `${m}:${s.toString().padStart(2, '0')}`;
  }

  private pctChange(prev: number, curr: number): number {
    if (prev === 0) return 0;
    return Math.round(((curr - prev) / prev) * 100);
  }
}
