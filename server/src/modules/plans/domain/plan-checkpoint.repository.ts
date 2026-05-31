import { PlanCheckpoint } from './plan-checkpoint.entity';

export interface PlanCheckpointRepository {
  save(checkpoint: PlanCheckpoint): Promise<PlanCheckpoint>;
  saveBatch(checkpoints: PlanCheckpoint[]): Promise<void>;
  findByPlan(planId: string, userId: string): Promise<PlanCheckpoint[]>;
  findByWeek(
    planId: string,
    weekNumber: number,
    userId: string,
  ): Promise<PlanCheckpoint | null>;
  update(
    planId: string,
    weekNumber: number,
    userId: string,
    patch: Partial<PlanCheckpoint>,
  ): Promise<void>;
}
