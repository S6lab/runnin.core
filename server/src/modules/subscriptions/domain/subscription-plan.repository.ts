import { SubscriptionPlan, SubscriptionPlanId } from './subscription-plan.entity';

export interface SubscriptionPlanRepository {
  findById(id: SubscriptionPlanId): Promise<SubscriptionPlan | null>;
  listAll(): Promise<SubscriptionPlan[]>;
  upsert(plan: SubscriptionPlan): Promise<void>;
}
