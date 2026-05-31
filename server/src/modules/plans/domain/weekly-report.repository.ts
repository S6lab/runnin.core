import { WeeklyReport } from './weekly-report.entity';

export interface WeeklyReportRepository {
  findByPlan(planId: string, userId: string): Promise<WeeklyReport[]>;
  findByWeek(planId: string, weekNumber: number, userId: string): Promise<WeeklyReport | null>;
  save(report: WeeklyReport): Promise<void>;
  update(
    planId: string,
    weekNumber: number,
    userId: string,
    data: Partial<WeeklyReport>,
  ): Promise<void>;
}
