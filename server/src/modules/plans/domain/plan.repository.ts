import { Plan } from './plan.entity';

export interface PlanRepository {
  findCurrent(userId: string): Promise<Plan | null>;
  findById(planId: string, userId: string): Promise<Plan | null>;
  create(plan: Plan): Promise<Plan>;
  update(planId: string, userId: string, data: Partial<Plan>): Promise<void>;
}
