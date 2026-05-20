import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { PartnerSubscription } from '../domain/partner-subscription.entity';
import { PartnerSubscriptionRepository } from '../domain/partner-subscription.repository';

/**
 * Collection top-level `subscriptions` — escala pra milhões de docs.
 * Query principal: igualdade em `identifier` (índice single-field automático).
 * Filtro de status é feito em memória (poucos docs por identificador).
 */
export class FirestorePartnerSubscriptionRepository
  implements PartnerSubscriptionRepository
{
  private col = () => getFirestore().collection('subscriptions');

  async findByIdentifier(identifier: string): Promise<PartnerSubscription[]> {
    if (!identifier) return [];
    const snap = await this.col().where('identifier', '==', identifier).get();
    return snap.docs.map((d) => ({ id: d.id, ...d.data() }) as PartnerSubscription);
  }

  async findById(id: string): Promise<PartnerSubscription | null> {
    const d = await this.col().doc(id).get();
    if (!d.exists) return null;
    return { id: d.id, ...d.data() } as PartnerSubscription;
  }

  async upsert(sub: PartnerSubscription): Promise<void> {
    const { id, ...data } = sub;
    await this.col().doc(id).set(data, { merge: true });
  }

  async update(id: string, data: Partial<PartnerSubscription>): Promise<void> {
    await this.col().doc(id).update(data as Record<string, unknown>);
  }
}
