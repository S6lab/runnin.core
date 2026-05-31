export type PeriodAnalysisStatus = 'pending' | 'ready';

export interface PeriodAnalysis {
  userId: string;
  runs: Array<{
    id: string;
    distanceM: number;
    durationS: number;
    avgPace?: string;
    avgBpm?: number;
    maxBpm?: number;
    type: string;
    date: string;
  }>;
  summary: string;
  status: PeriodAnalysisStatus;
  generatedAt: string;
}
