import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { PeriodAnalysis } from '../domain/period-analysis.entity';
import { PeriodAnalysisRepository } from '../domain/period-analysis.repository';

export class FirestorePeriodAnalysisRepository implements PeriodAnalysisRepository {
  private doc = (userId: string) => getFirestore().collection(`users/${userId}/period-analysis`).doc('analysis');

  async findByUserId(userId: string): Promise<PeriodAnalysis | null> {
    const snap = await this.doc(userId).get();
    if (!snap.exists) return null;
    const data = snap.data() ?? {};
    return {
      userId,
      runs: data['runs'] ?? [],
      summary: data['summary'] ?? '',
      status: (data['status'] ?? 'pending') as PeriodAnalysis['status'],
      generatedAt: data['generatedAt'] ?? '',
    };
  }

  async save(analysis: PeriodAnalysis): Promise<void> {
    const { userId, runs, ...payload } = analysis;
    await this.doc(userId).set({
      ...payload,
      runs,
    });
  }
}
