import { PartnerSubscription } from './partner-subscription.entity';

export interface PartnerSubscriptionRepository {
  /** Assinaturas por identificador normalizado (telefone/cpf/email). */
  findByIdentifier(identifier: string): Promise<PartnerSubscription[]>;
  findById(id: string): Promise<PartnerSubscription | null>;
  upsert(sub: PartnerSubscription): Promise<void>;
  update(id: string, data: Partial<PartnerSubscription>): Promise<void>;
}
