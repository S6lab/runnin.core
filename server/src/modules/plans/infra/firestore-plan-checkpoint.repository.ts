import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { PlanCheckpoint } from '../domain/plan-checkpoint.entity';
import { PlanCheckpointRepository } from '../domain/plan-checkpoint.repository';

function stripUndefined<T extends object>(data: T): Partial<T> {
  return Object.fromEntries(
    Object.entries(data).filter(([, v]) => v !== undefined),
  ) as Partial<T>;
}

export class FirestorePlanCheckpointRepository
  implements PlanCheckpointRepository
{
  private col = (userId: string, planId: string) =>
    getFirestore().collection(`users/${userId}/plans/${planId}/checkpoints`);

  async save(checkpoint: PlanCheckpoint): Promise<PlanCheckpoint> {
    const { id, userId, planId, ...data } = checkpoint;
    await this.col(userId, planId).doc(id).set(stripUndefined(data));
    return checkpoint;
  }

  async saveBatch(checkpoints: PlanCheckpoint[]): Promise<void> {
    if (checkpoints.length === 0) return;
    const db = getFirestore();
    const batch = db.batch();
    for (const cp of checkpoints) {
      const { id, userId, planId, ...data } = cp;
      const ref = this.col(userId, planId).doc(id);
      batch.set(ref, stripUndefined(data));
    }
    await batch.commit();
  }

  async findByPlan(planId: string, userId: string): Promise<PlanCheckpoint[]> {
    const snap = await this.col(userId, planId).orderBy('weekNumber', 'asc').get();
    return snap.docs.map(
      (d) => ({ id: d.id, planId, userId, ...d.data() } as PlanCheckpoint),
    );
  }

  async findByWeek(
    planId: string,
    weekNumber: number,
    userId: string,
  ): Promise<PlanCheckpoint | null> {
    const id = `${planId}_${weekNumber}`;
    const d = await this.col(userId, planId).doc(id).get();
    if (!d.exists) return null;
    return { id: d.id, planId, userId, ...d.data() } as PlanCheckpoint;
  }

  async update(
    planId: string,
    weekNumber: number,
    userId: string,
    patch: Partial<PlanCheckpoint>,
  ): Promise<void> {
    const id = `${planId}_${weekNumber}`;
    await this.col(userId, planId)
      .doc(id)
      .update(stripUndefined(patch as Record<string, unknown>));
  }
}
