import { CoachReport } from '../domain/coach-report.entity';
import { CoachReportRepository } from '../domain/coach-report.repository';

export type GetCoachReportResult =
  | { status: 'pending' }
  | { status: 'ready'; report: CoachReport };

export class GetCoachReportUseCase {
  constructor(private readonly reports: CoachReportRepository) {}

  async execute(userId: string, runId: string): Promise<GetCoachReportResult> {
    const report = await this.reports.findByRunId(userId, runId);
    if (!report || report.status !== 'ready') return { status: 'pending' };
    return { status: 'ready', report };
  }
}
