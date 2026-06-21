import { Plan, PlanRevision, PlanWeek } from './plan.entity';

export interface PlanRepository {
  findCurrent(userId: string): Promise<Plan | null>;
  /** Todos os planos do usuário (ordenados por createdAt asc). Usado pra
   *  cobrir histórico de planos no breakdown de stats. */
  listByUser(userId: string): Promise<Plan[]>;
  findById(planId: string, userId: string): Promise<Plan | null>;
  create(plan: Plan): Promise<Plan>;
  update(planId: string, userId: string, data: Partial<Plan>): Promise<void>;
  /** Append idempotente do log de revisão semanal: roda em transação Firestore,
   *  relê o plano, e só grava se ainda NÃO existir entry com o mesmo weekNumber
   *  em `plan.revisions[]`. Quando já existe, retorna `appended: false` sem
   *  tocar em `adjustedWeeks` (presume que pertence à revisão pré-existente).
   *  Defense-in-depth pra cron de domingo; redundante com o guard da coleção
   *  PlanRevision, mas protege o array do plano de races / paths paralelos. */
  appendWeeklyRevisionLog(
    planId: string,
    userId: string,
    weekNumber: number,
    payload: { logEntry: PlanRevision; adjustedWeeks: PlanWeek[]; updatedAt: string },
  ): Promise<{ appended: boolean }>;
}
