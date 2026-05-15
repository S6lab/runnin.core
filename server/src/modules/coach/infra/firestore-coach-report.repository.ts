import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { CoachReport } from '../domain/coach-report.entity';
import { CoachReportRepository } from '../domain/coach-report.repository';

export class FirestoreCoachReportRepository implements CoachReportRepository {
  private doc = (userId: string, runId: string) =>
    getFirestore()
      .collection(`users/${userId}/runs/${runId}/reports`)
      .doc(runId);

  async findByRunId(userId: string, runId: string): Promise<CoachReport | null> {
    const snap = await this.doc(userId, runId).get();
    if (!snap.exists) return null;
    const data = snap.data() ?? {};
    return {
      runId,
      userId,
      summary: data['summary'] ?? '',
      status: (data['status'] ?? 'pending') as CoachReport['status'],
      generatedAt: data['generatedAt'] ?? '',
    };
  }

  async save(report: CoachReport): Promise<void> {
    const { runId, userId, ...payload } = report;
    await this.doc(userId, runId).set(payload);
  }
}
