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

  async listGpsPoints(runId: string, userId: string, limit = 5000): Promise<GpsPoint[]> {
    const snap = await this.gpscol(userId, runId).orderBy('ts', 'asc').limit(limit).get();
    return snap.docs.map(d => d.data() as GpsPoint);
  }

  async findByUser(userId: string, limit: number, cursor?: string): Promise<{ runs: Run[]; nextCursor?: string }> {
    // Fetch com buffer 3x pra absorver descarte de runs curtas e ainda
    // entregar `limit` válidas. User reportou que runs descartadas (<30s
    // ou <100m) entravam no histórico e poluíam pace por todo o app —
    // filtrar AQUI cobre TODOS os callers (home/profile/histórico/zonas).
    // O cursor segue sendo o último createdAt entregue.
    const fetchSize = (limit + 1) * 3;
    let query = this.col(userId).orderBy('createdAt', 'desc').limit(fetchSize);
    if (cursor) query = query.startAfter(cursor);

    const snap = await query.get();
    const valid = snap.docs
      .map(d => ({ id: d.id, userId, ...d.data() }) as Run)
      .filter(_isValidRun);
    const hasMore = valid.length > limit;
    const runs = valid.slice(0, limit);
    return { runs, nextCursor: hasMore ? runs[runs.length - 1].createdAt : undefined };
  }

  async findByDateRange(userId: string, from: Date, to: Date): Promise<Run[]> {
    // Só range em createdAt + orderBy (single-field, auto-indexado). Filtrar
    // status='completed' em MEMÓRIA — combinar where(status==) com range exige
    // índice composto que não existe em staging (gerava 500 em /stats/*).
    const snap = await this.col(userId)
      .where('createdAt', '>=', from.toISOString())
      .where('createdAt', '<=', to.toISOString())
      .orderBy('createdAt', 'asc')
      .get();
    return snap.docs
      .map(d => ({ id: d.id, userId, ...d.data() }) as Run)
      .filter(_isValidRun);
  }
}

/// Critério canônico de "run analisável": completed + >=30s + >=100m.
/// Mesmos thresholds aplicados no client (get_home_data_use_case.dart) e
/// nos stats endpoints (get-stats-aggregate/breakdown). Mantém histórico
/// e médias de pace livres de starts acidentais e abandonos curtos.
function _isValidRun(r: Run): boolean {
  return r.status === 'completed'
    && (r.distanceM ?? 0) >= 100
    && (r.durationS ?? 0) >= 30;
}
