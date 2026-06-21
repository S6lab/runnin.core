import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { logger } from '@shared/logger/logger';
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

  async saveIfAbsent(revision: PlanRevision): Promise<{ created: boolean }> {
    const { id, userId, ...data } = revision;
    try {
      await this.revisionsCol(userId).doc(id).create(data);
      return { created: true };
    } catch (err) {
      // Firestore lança ALREADY_EXISTS (code 6 / "6 ALREADY_EXISTS") quando
      // o doc já existe — sinal de que outro worker (cron retry, Cloud Task
      // redelivery, race com path admin) já gravou. Bail silencioso.
      const msg = err instanceof Error ? err.message : String(err);
      const code = (err as { code?: number | string } | undefined)?.code;
      if (code === 6 || code === 'already-exists' || msg.includes('ALREADY_EXISTS')) {
        return { created: false };
      }
      throw err;
    }
  }

  async findById(id: string, userId: string): Promise<PlanRevision | null> {
    const d = await this.revisionsCol(userId).doc(id).get();
    if (!d.exists) return null;
    return { id: d.id, userId, ...d.data() } as PlanRevision;
  }

  async listByPlan(planId: string, userId: string): Promise<PlanRevision[]> {
    try {
      const snap = await this.revisionsCol(userId)
        .where('planId', '==', planId)
        .orderBy('createdAt', 'desc')
        .get();
      return snap.docs.map((d) => ({ id: d.id, userId, ...d.data() } as PlanRevision));
    } catch (err) {
      // FAILED_PRECONDITION: composite index (planId+createdAt) ainda não
      // criado no Firestore. Em vez de 500, retorna [] e loga — UI mostra
      // "sem revisões" ao invés de quebrar. Fix permanente: criar o index
      // em firestore.indexes.json + firebase deploy --only firestore:indexes.
      const msg = err instanceof Error ? err.message : String(err);
      if (msg.includes('FAILED_PRECONDITION') || msg.includes('requires an index')) {
        logger.warn('plan.revisions.list_missing_index', { planId, userId, err: msg });
        // Fallback: tenta sem orderBy (não precisa de índice composto), ordena em memória.
        try {
          const snap = await this.revisionsCol(userId)
            .where('planId', '==', planId)
            .get();
          const docs = snap.docs.map((d) => ({ id: d.id, userId, ...d.data() } as PlanRevision));
          return docs.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
        } catch {
          return [];
        }
      }
      throw err;
    }
  }

  async findByUser(userId: string): Promise<PlanRevision[]> {
    try {
      const snap = await this.revisionsCol(userId)
        .orderBy('createdAt', 'desc')
        .get();
      return snap.docs.map((d) => ({ id: d.id, userId, ...d.data() } as PlanRevision));
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      if (msg.includes('FAILED_PRECONDITION') || msg.includes('requires an index')) {
        logger.warn('plan.revisions.find_user_missing_index', { userId, err: msg });
        return [];
      }
      throw err;
    }
  }
}
