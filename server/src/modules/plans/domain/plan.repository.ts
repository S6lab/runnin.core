import { Plan } from './plan.entity';

export interface PlanRepository {
  findCurrent(userId: string): Promise<Plan | null>;
  /** Todos os planos do usuário (ordenados por createdAt asc). Usado pra
   *  cobrir histórico de planos no breakdown de stats. */
  listByUser(userId: string): Promise<Plan[]>;
  findById(planId: string, userId: string): Promise<Plan | null>;
  create(plan: Plan): Promise<Plan>;
  update(planId: string, userId: string, data: Partial<Plan>): Promise<void>;
}
