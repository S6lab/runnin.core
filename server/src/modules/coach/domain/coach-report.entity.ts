export type CoachReportStatus = 'pending' | 'ready';

export interface CoachReport {
  runId: string;
  userId: string;
  summary: string;
  status: CoachReportStatus;
  generatedAt: string;
}
