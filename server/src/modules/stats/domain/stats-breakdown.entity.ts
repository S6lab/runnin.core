import { StatsPeriod } from './stats-aggregate.entity';

/**
 * Stats consolidados da aba DADOS do Histórico, respeitando o período
 * selecionado (week/month/threeMonths). `level`/`levelName`/`streak` são
 * LIFETIME (não dependem do filtro — período-bound não faz sentido pra
 * streak/nível); os demais são do período. `totalXp` é o XP do período.
 */
export interface BreakdownStats {
  runs: number;
  totalDistanceKm: number;
  avgDistanceKm: number;
  totalDurationS: number;
  avgPace: string | null; // "M:SS"
  calories: number;
  level: number; // 1-based, lifetime
  levelName: string; // lifetime
  avgBpm: number | null;
  maxBpm: number | null;
  streak: number; // dias consecutivos com corrida (lifetime)
  totalXp: number; // XP do período
}

/** Um item do gráfico de volume (dia/semana/mês conforme o período). */
export interface VolumeBucket {
  label: string;
  plannedKm: number;
  realizedKm: number;
}

/** Um item do gráfico de pace (seg/km; null quando não há dado). */
export interface PaceBucket {
  label: string;
  projectedPaceSec: number | null;
  avgPaceSec: number | null;
}

export interface StatsBreakdown {
  period: StatsPeriod;
  stats: BreakdownStats;
  volume: VolumeBucket[];
  pace: PaceBucket[];
}
