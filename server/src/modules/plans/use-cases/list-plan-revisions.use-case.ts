import { PlanRevisionRepository } from '../domain/plan-revision.repository';
import { PlanRevision } from '../domain/plan-revision.entity';

export class ListPlanRevisionsUseCase {
  constructor(private readonly revisions: PlanRevisionRepository) {}

  async execute(planId: string, userId: string): Promise<PlanRevision[]> {
    return await this.revisions.listByPlan(planId, userId);
  }
}
