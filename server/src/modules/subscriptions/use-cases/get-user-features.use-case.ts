import { UserRepository } from '@modules/users/domain/user.repository';
import { SubscriptionPlanRepository } from '../domain/subscription-plan.repository';
import { SubscriptionPlan, SubscriptionPlanId } from '../domain/subscription-plan.entity';
import { PlanFeatures } from '../domain/plan-features';
import { FREEMIUM_PLAN } from '../domain/defaults';

/**
 * Resolve qual plano um user tem AGORA + retorna as features.
 *
 * Estratégia de resolução (em ordem):
 * 1. Lê `subscriptionPlanId` do UserProfile (campo novo)
 * 2. Se ausente, infere via legado `premium: boolean` (retrocompat)
 * 3. Se ambos ausentes, default freemium
 */
export class GetUserFeaturesUseCase {
  constructor(
    private readonly users: UserRepository,
    private readonly plans: SubscriptionPlanRepository,
  ) {}

  async resolvePlanId(uid: string): Promise<SubscriptionPlanId> {
    const profile = await this.users.findById(uid);
    if (!profile) return 'freemium';
    // Campo novo tem prioridade
    const explicit = (profile as { subscriptionPlanId?: SubscriptionPlanId })
      .subscriptionPlanId;
    if (explicit) return explicit;
    // Retrocompat: campo legacy `premium: boolean`
    if (profile.premium) return 'pro';
    if (profile.premiumUntil && new Date(profile.premiumUntil) > new Date()) return 'pro';
    return 'freemium';
  }

  async getPlan(uid: string): Promise<SubscriptionPlan> {
    const id = await this.resolvePlanId(uid);
    return (await this.plans.findById(id)) ?? FREEMIUM_PLAN;
  }

  async getFeatures(uid: string): Promise<PlanFeatures> {
    const plan = await this.getPlan(uid);
    return plan.features;
  }

  async hasFeature(uid: string, feature: keyof PlanFeatures): Promise<boolean> {
    const features = await this.getFeatures(uid);
    return features[feature] === true;
  }
}
