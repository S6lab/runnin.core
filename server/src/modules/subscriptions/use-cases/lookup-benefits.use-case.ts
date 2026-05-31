import { getAuth } from '@shared/infra/firebase/firebase.client';
import { PartnerSubscriptionRepository } from '../domain/partner-subscription.repository';
import { SubscriptionPlanRepository } from '../domain/subscription-plan.repository';
import { SubscriptionPlan } from '../domain/subscription-plan.entity';
import {
  PartnerSubscription,
  isClaimable,
  normalizePhone,
} from '../domain/partner-subscription.entity';
import { DEFAULT_PLANS } from '../domain/defaults';

export interface BenefitView {
  subscription: PartnerSubscription;
  plan: SubscriptionPlan | null;
}

/**
 * Busca os benefícios (assinaturas de parceiro) do usuário pelo identificador.
 * Inicialmente só telefone (do Firebase Auth). Silencioso — não falha o fluxo
 * se o user não tiver telefone/benefício.
 */
export class LookupBenefitsUseCase {
  constructor(
    private readonly repo: PartnerSubscriptionRepository,
    private readonly planRepo: SubscriptionPlanRepository,
  ) {}

  async execute(userId: string): Promise<BenefitView[]> {
    let phone: string | undefined;
    try {
      const authUser = await getAuth().getUser(userId);
      phone = authUser.phoneNumber ?? undefined;
    } catch {
      phone = undefined;
    }
    if (!phone) return [];

    const subs = await this.repo.findByIdentifier(normalizePhone(phone));
    const claimable = subs.filter((s) => isClaimable(s.status));

    return Promise.all(
      claimable.map(async (s) => ({
        subscription: s,
        plan: await this.resolvePlanByServiceId(s.serviceId),
      })),
    );
  }

  /** Resolve o plano do app casando `serviceId` (parceiro) com o catálogo. */
  private async resolvePlanByServiceId(
    serviceId: string,
  ): Promise<SubscriptionPlan | null> {
    const all = await this.planRepo.listAll().catch(() => [] as SubscriptionPlan[]);
    const pool = all.length > 0 ? all : DEFAULT_PLANS;
    return pool.find((p) => p.serviceId === serviceId) ?? null;
  }
}
