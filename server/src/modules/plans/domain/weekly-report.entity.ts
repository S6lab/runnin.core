export type WeeklyReportStatus = 'pending' | 'ready' | 'failed';

export interface WeeklyReportMetrics {
  plannedSessions: number;
  completedRuns: number;
  plannedDistanceKm: number;
  actualDistanceKm: number;
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
