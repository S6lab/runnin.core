import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { WeeklyReport } from '../domain/weekly-report.entity';
import { WeeklyReportRepository } from '../domain/weekly-report.repository';

function stripUndefined<T extends object>(data: T): Partial<T> {
  return Object.fromEntries(
    Object.entries(data).filter(([, v]) => v !== undefined),
  ) as Partial<T>;
}

export class FirestoreWeeklyReportRepository implements WeeklyReportRepository {
  private col = (userId: string, planId: string) =>
    getFirestore().collection(`users/${userId}/plans/${planId}/weekly_reports`);

  async findByPlan(planId: string, userId: string): Promise<WeeklyReport[]> {
    const snap = await this.col(userId, planId).orderBy('weekNumber', 'asc').get();
    return snap.docs.map(
      (d) => ({ id: d.id, userId, planId, ...d.data() } as WeeklyReport),
    );
  }

  async findByWeek(
    planId: string,
    weekNumber: number,
    userId: string,
  ): Promise<WeeklyReport | null> {
    const d = await this.col(userId, planId).doc(String(weekNumber)).get();
    if (!d.exists) return null;
    return { id: d.id, userId, planId, ...d.data() } as WeeklyReport;
  }

  async save(report: WeeklyReport): Promise<void> {
    const { id, userId, planId, ...data } = report;
    await this.col(userId, planId).doc(id).set(stripUndefined(data));
  }

  async update(
    planId: string,
    weekNumber: number,
    userId: string,
    data: Partial<WeeklyReport>,
  ): Promise<void> {
    await this.col(userId, planId)
      .doc(String(weekNumber))
      .update(stripUndefined(data as Record<string, unknown>));
  }
}
