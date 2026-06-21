import { PlanRevision } from './plan-revision.entity';

export interface PlanRevisionRepository {
  save(revision: PlanRevision): Promise<PlanRevision>;
  /** Cria a revisão SE o id ainda não existir. Atômico (Firestore `.create()`).
   *  Usado pelo cron de domingo com id determinístico `${planId}_w${week}` pra
   *  blindar contra retries do Cloud Scheduler / redelivery do Cloud Tasks. */
  saveIfAbsent(revision: PlanRevision): Promise<{ created: boolean }>;
  findById(id: string, userId: string): Promise<PlanRevision | null>;
  listByPlan(planId: string, userId: string): Promise<PlanRevision[]>;
  findByUser(userId: string): Promise<PlanRevision[]>;
}
