import { CoachReport } from './coach-report.entity';

export interface CoachReportRepository {
  findByRunId(userId: string, runId: string): Promise<CoachReport | null>;
  save(report: CoachReport): Promise<void>;
}
