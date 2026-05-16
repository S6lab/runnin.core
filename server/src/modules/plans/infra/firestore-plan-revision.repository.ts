import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { PlanRevision } from '../domain/plan-revision.entity';
import { PlanRevisionRepository } from '../domain/plan-revision.repository';

export class FirestorePlanRevisionRepository implements PlanRevisionRepository {
  private revisionsCol = (userId: string) =>
    getFirestore().collection(`users/${userId}/planRevisions`);

  async save(revision: PlanRevision): Promise<PlanRevision> {
    const { id, userId, ...data } = revision;
    await this.revisionsCol(userId).doc(id).set(data);
    return revision;
  }

  async findById(id: string, userId: string): Promise<PlanRevision | null> {
    const d = await this.revisionsCol(userId).doc(id).get();
    if (!d.exists) return null;
    return { id: d.id, userId, ...d.data() } as PlanRevision;
  }

  async listByPlan(planId: string, userId: string): Promise<PlanRevision[]> {
    const snap = await this.revisionsCol(userId)
      .where('planId', '==', planId)
      .orderBy('createdAt', 'desc')
      .get();

    return snap.docs.map((d) => ({ id: d.id, userId, ...d.data() } as PlanRevision));
  }

  async findByUser(userId: string): Promise<PlanRevision[]> {
    const snap = await this.revisionsCol(userId)
      .orderBy('createdAt', 'desc')
      .get();

    return snap.docs.map((d) => ({ id: d.id, userId, ...d.data() } as PlanRevision));
  }
}
