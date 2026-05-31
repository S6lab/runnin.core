export type StatsPeriod = 'week' | 'month' | 'threeMonths';

export interface StatsTotals {
  count: number;
  totalDistanceM: number;
  totalDurationS: number;
  totalCalories: number;
  totalXp: number;
}

export interface StatsAverages {
  avgPaceMinKm: string | null;
  avgBpm: number | null;
  maxBpm: number | null;
  avgDistanceKmPerRun: number;
}

export interface StatsDeltas {
  pacePctVsPrev: number | null;
  volumePctVsPrev: number | null;
  bpmDeltaBpm: number | null;
  runsCountDelta: number;
}

export interface WeeklyVolumeEntry {
  weekLabel: string;
  plannedKm: number;
  executedKm: number;
}

export interface TrendEntry {
  date: string;
  avgPaceMinKm: string | null;
  avgBpm: number | null;
}

export interface StatsAggregate {
  totals: StatsTotals;
  averages: StatsAverages;
  deltas: StatsDeltas;
  zoneDistribution: number[];
  weeklyVolume: WeeklyVolumeEntry[];
  paceTrend: TrendEntry[];
  bpmTrend: TrendEntry[];
}
