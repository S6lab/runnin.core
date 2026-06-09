export type WeeklyReportStatus = 'pending' | 'ready' | 'failed';

export interface WeeklyReportMetrics {
  plannedSessions: number;
  completedRuns: number;
  plannedDistanceKm: number;
  actualDistanceKm: number;
  /// Distância feita em runs livres (sem planSessionId). Subset de
  /// actualDistanceKm. Coach usa pra explicar: "você ficou 1km abaixo
  /// no easy de quarta mas correu 1km livre depois — fechou o volume".
  freeRunsDistanceKm: number;
  /// Distância feita em sessões vinculadas ao plano (com planSessionId).
  /// plannedRunsDistanceKm + freeRunsDistanceKm == actualDistanceKm.
  plannedRunsDistanceKm: number;
  completionRate: number; // 0-1
  avgBpm?: number;
  maxBpm?: number;
  avgPaceStr?: string;
  totalDurationS: number;
}

export interface WeeklyReport {
  id: string;
  planId: string;
  userId: string;
  weekNumber: number;
  weekStart: string;
  weekEnd: string;
  metrics: WeeklyReportMetrics;
  runIds: string[];
  summary: string;
  coachHighlights: string[];
  status: WeeklyReportStatus;
  generatedAt: string;
  createdAt: string;
}
