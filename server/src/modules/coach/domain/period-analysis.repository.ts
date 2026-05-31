import { PeriodAnalysis } from './period-analysis.entity';

export interface PeriodAnalysisRepository {
  findByUserId(userId: string): Promise<PeriodAnalysis | null>;
  save(analysis: PeriodAnalysis): Promise<void>;
}
