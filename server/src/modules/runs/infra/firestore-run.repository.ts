import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { Run, GpsPoint } from '../domain/run.entity';
import { RunRepository } from '../domain/run.repository';
import { NotFoundError } from '@shared/errors/app-error';

const GPS_ACCURACY_THRESHOLD = 15; // metros — filtra ruído

function stripUndefined<T extends object>(data: T): Partial<T> {
  return Object.fromEntries(
    Object.entries(data).filter(([, value]) => value !== undefined),
  ) as Partial<T>;
}

export class FirestoreRunRepository implements RunRepository {
  private col = (userId: string) => getFirestore().collection(`users/${userId}/runs`);
  private gpscol = (userId: string, runId: string) =>
    getFirestore().collection(`users/${userId}/runs/${runId}/gps_points`);

  async create(run: Run): Promise<void> {
    const { id, userId, ...data } = run;
    await this.col(userId).doc(id).set(stripUndefined(data));
  }

  async findById(id: string, userId: string): Promise<Run | null> {
    const doc = await this.col(userId).doc(id).get();
    if (!doc.exists) return null;
    return { id: doc.id, userId, ...doc.data() } as Run;
  }

  async update(id: string, userId: string, data: Partial<Run>): Promise<void> {
    await this.col(userId)
      .doc(id)
      .update(stripUndefined(data as Record<string, unknown>));
  }

  async addGpsBatch(runId: string, userId: string, points: GpsPoint[]): Promise<void> {
    const filtered = points.filter(p => p.accuracy <= GPS_ACCURACY_THRESHOLD);
    if (filtered.length === 0) return;

    const db = getFirestore();
    const batch = db.batch();
    const col = this.gpscol(userId, runId);

    for (const point of filtered) {
      batch.set(col.doc(), stripUndefined(point));
    }
    await batch.commit();
  }

  async findByUser(userId: string, limit: number, cursor?: string): Promise<{ runs: Run[]; nextCursor?: string }> {
    let query = this.col(userId).orderBy('createdAt', 'desc').limit(limit + 1);
    if (cursor) query = query.startAfter(cursor);

    const snap = await query.get();
    const docs = snap.docs;
    const hasMore = docs.length > limit;
    const runs = docs.slice(0, limit).map(d => ({ id: d.id, userId, ...d.data() }) as Run);
    return { runs, nextCursor: hasMore ? runs[runs.length - 1].createdAt : undefined };
  }

  async findByDateRange(userId: string, from: Date, to: Date): Promise<Run[]> {
    const snap = await this.col(userId)
      .where('status', '==', 'completed')
      .where('createdAt', '>=', from.toISOString())
      .where('createdAt', '<=', to.toISOString())
      .orderBy('createdAt', 'asc')
      .get();
    return snap.docs.map(d => ({ id: d.id, userId, ...d.data() }) as Run);
  }
}
