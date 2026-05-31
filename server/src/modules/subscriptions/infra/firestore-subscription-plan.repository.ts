import { getFirestore } from '@shared/infra/firebase/firebase.client';
import {
  SubscriptionPlan,
  SubscriptionPlanId,
} from '../domain/subscription-plan.entity';
import { SubscriptionPlanRepository } from '../domain/subscription-plan.repository';
import { DEFAULT_PLANS, FREEMIUM_PLAN, PRO_PLAN } from '../domain/defaults';

const COLLECTION = 'subscription_plans';
const CACHE_TTL_MS = 60_000;

/**
 * Cache em memória 60s. Plans raramente mudam — evita N+1 Firestore reads
 * em todo request autenticado (que vai checar features).
 *
 * Fallback hardcoded (FREEMIUM/PRO) garante que app funciona mesmo se
 * Firestore estiver indisponível ou docs ainda não tiverem sido seedados.
 */
export class FirestoreSubscriptionPlanRepository
  implements SubscriptionPlanRepository
{
  private cache: Map<SubscriptionPlanId, { plan: SubscriptionPlan; expiresAt: number }> =
    new Map();

  private col() {
    return getFirestore().collection(COLLECTION);
  }

  async findById(id: SubscriptionPlanId): Promise<SubscriptionPlan | null> {
    const cached = this.cache.get(id);
    if (cached && cached.expiresAt > Date.now()) return cached.plan;

    try {
      const doc = await this.col().doc(id).get();
      if (doc.exists) {
        const plan = { id, ...doc.data() } as SubscriptionPlan;
        this.cache.set(id, { plan, expiresAt: Date.now() + CACHE_TTL_MS });
        return plan;
      }
    } catch {
      // Firestore down — fallback pra defaults
    }
    return this.fallback(id);
  }

  async listAll(): Promise<SubscriptionPlan[]> {
    try {
      const snap = await this.col().get();
      const plans = snap.docs.map(
        (d) => ({ id: d.id, ...d.data() } as SubscriptionPlan),
      );
      if (plans.length > 0) return plans;
    } catch {
      // ignore
    }
    return DEFAULT_PLANS;
  }

  async upsert(plan: SubscriptionPlan): Promise<void> {
    const { id, ...data } = plan;
    await this.col().doc(id).set(data, { merge: true });
    this.cache.delete(id);
  }

  private fallback(id: SubscriptionPlanId): SubscriptionPlan {
    return id === 'pro' ? PRO_PLAN : FREEMIUM_PLAN;
  }
}
