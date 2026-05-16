import { PlanRevision } from './plan-revision.entity';

export interface PlanRevisionRepository {
  save(revision: PlanRevision): Promise<PlanRevision>;
  findById(id: string, userId: string): Promise<PlanRevision | null>;
  listByPlan(planId: string, userId: string): Promise<PlanRevision[]>;
  findByUser(userId: string): Promise<PlanRevision[]>;
}
