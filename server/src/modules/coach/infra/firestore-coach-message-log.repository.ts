import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { CoachMessageLog } from '../domain/coach-message-log.entity';
import { CoachMessageLogRepository } from '../domain/coach-message-log.repository';

function stripUndefined<T extends object>(data: T): Partial<T> {
  return Object.fromEntries(
    Object.entries(data).filter(([, value]) => value !== undefined),
  ) as Partial<T>;
}

export class FirestoreCoachMessageLogRepository implements CoachMessageLogRepository {
  private col = (userId: string, runId: string) =>
    getFirestore().collection(`users/${userId}/runs/${runId}/coach_messages`);

  async save(log: CoachMessageLog): Promise<void> {
    const { id, ...data } = log;
    await this.col(log.userId, log.runId).doc(id).set(stripUndefined(data));
  }

  async listByRun(userId: string, runId: string): Promise<CoachMessageLog[]> {
    const snap = await this.col(userId, runId)
      .orderBy('createdAt', 'asc')
      .limit(200)
      .get();
    return snap.docs.map(d => ({ id: d.id, ...d.data() }) as CoachMessageLog);
  }
}
