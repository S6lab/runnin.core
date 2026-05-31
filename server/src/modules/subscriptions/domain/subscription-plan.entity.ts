import { PlanFeatures, PlanLimits } from './plan-features';

/** Catálogo aberto: novos planos de operadoras podem ser adicionados sem mudar tipo. */
export type SubscriptionPlanId = 'freemium' | 'pro' | 'claro_basic' | string;

/** Quem oferece/cobra o plano. */
export type SubscriptionProvider = 's6lab' | 'claro';

export type SubscriptionStatus = 'active' | 'cancelled' | 'expired' | 'trial';

export interface SubscriptionPlan {
  id: SubscriptionPlanId;
  /** Quem oferece o plano (operadora ou marca própria). */
  provider: SubscriptionProvider;
  /**
   * Identificador externo do serviço junto ao provider — ex: SKU da Apple/Play,
   * billing code da Claro, etc. Vazio em planos puramente internos.
   */
  serviceId: string;
  /** Display title. */
  name: string;
  priceLabel: string;
  periodLabel: string;
  features: PlanFeatures;
  limits: PlanLimits;
  active: boolean;
  createdAt: string;
  updatedAt: string;
}
