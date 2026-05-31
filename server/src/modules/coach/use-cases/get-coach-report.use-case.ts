import { CoachReport } from '../domain/coach-report.entity';
import { CoachReportRepository } from '../domain/coach-report.repository';

export type GetCoachReportResult =
  | { status: 'pending' }
  | { status: 'ready'; report: CoachReport };

export class GetCoachReportUseCase {
  constructor(private readonly reports: CoachReportRepository) {}

  async execute(userId: string, runId: string): Promise<GetCoachReportResult> {
    const report = await this.reports.findByRunId(userId, runId);
    // Two-phase: aceita summary_ready/enriched/ready (legacy) como "tem texto pra mostrar".
    // Sem isso, a UI ficava "Relatório não disponível" mesmo com summary gravado.
    if (!report || !report.summary) return { status: 'pending' };
    return { status: 'ready', report };
  }
}
