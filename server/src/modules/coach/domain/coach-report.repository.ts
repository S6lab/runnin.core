import { CoachReport } from './coach-report.entity';

export interface CoachReportRepository {
  findByRunId(userId: string, runId: string): Promise<CoachReport | null>;
  /** Batch read pra agregação de período (Histórico). Devolve só os
   *  reports que existem — runs sem report não aparecem. */
  findByRunIds(userId: string, runIds: string[]): Promise<CoachReport[]>;
  save(report: CoachReport): Promise<void>;
}
