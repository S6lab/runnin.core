import { PlanFeatures, PlanLimits } from './plan-features';

export type SubscriptionPlanId = 'freemium' | 'pro';

export type SubscriptionStatus = 'active' | 'cancelled' | 'expired' | 'trial';

export interface SubscriptionPlan {
  id: SubscriptionPlanId;
  name: string;
  priceLabel: string;
  periodLabel: string;
  features: PlanFeatures;
  limits: PlanLimits;
  active: boolean;
  createdAt: string;
  updatedAt: string;
}
