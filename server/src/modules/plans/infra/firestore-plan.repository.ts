import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { Plan, PlanRevision, PlanWeek } from '../domain/plan.entity';
import { PlanRepository } from '../domain/plan.repository';

export class FirestorePlanRepository implements PlanRepository {
  private col = (userId: string) => getFirestore().collection(`users/${userId}/plans`);

  async findCurrent(userId: string): Promise<Plan | null> {
    const snap = await this.col(userId).get();
    if (snap.empty) return null;

    const docs = [...snap.docs].sort((a, b) => {
      const aData = a.data() as Record<string, unknown>;
      const bData = b.data() as Record<string, unknown>;
      const aCreatedAt =
        typeof aData['createdAt'] === 'string' ? aData['createdAt'] : '';
      const bCreatedAt =
        typeof bData['createdAt'] === 'string' ? bData['createdAt'] : '';
      return bCreatedAt.localeCompare(aCreatedAt);
    });

    const d = docs[0]!;
    return { id: d.id, userId, ...d.data() } as Plan;
  }

  async listByUser(userId: string): Promise<Plan[]> {
    const snap = await this.col(userId).get();
    if (snap.empty) return [];
    return snap.docs
      .map((d) => ({ id: d.id, userId, ...d.data() }) as Plan)
      .sort((a, b) => (a.createdAt ?? '').localeCompare(b.createdAt ?? ''));
  }

  async findById(planId: string, userId: string): Promise<Plan | null> {
    const d = await this.col(userId).doc(planId).get();
    if (!d.exists) return null;
    return { id: d.id, userId, ...d.data() } as Plan;
  }

  async create(plan: Plan): Promise<Plan> {
    const { id, userId, ...data } = plan;
    await this.col(userId).doc(id).set(data);
    return plan;
  }

  async update(planId: string, userId: string, data: Partial<Plan>): Promise<void> {
    await this.col(userId).doc(planId).update(data as Record<string, unknown>);
  }

  async appendWeeklyRevisionLog(
    planId: string,
    userId: string,
    weekNumber: number,
    payload: { logEntry: PlanRevision; adjustedWeeks: PlanWeek[]; updatedAt: string },
  ): Promise<{ appended: boolean }> {
    const db = getFirestore();
    const ref = this.col(userId).doc(planId);
    return db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) return { appended: false };
      const data = snap.data() as Partial<Plan>;
      const current = (data.revisions ?? []) as PlanRevision[];
      if (current.some((r) => r.weekNumber === weekNumber)) {
        return { appended: false };
      }
      tx.update(ref, {
        adjustedWeeks: payload.adjustedWeeks,
        revisions: [...current, payload.logEntry],
        updatedAt: payload.updatedAt,
      });
      return { appended: true };
    });
  }
}
