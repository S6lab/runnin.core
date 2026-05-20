import { getAuth } from '@shared/infra/firebase/firebase.client';
import { PartnerSubscriptionRepository } from '../domain/partner-subscription.repository';
import { UserRepository } from '@modules/users/domain/user.repository';
import {
  isClaimable,
  normalizePhone,
} from '../domain/partner-subscription.entity';
import { AppError, NotFoundError } from '@shared/errors/app-error';

export class BenefitNotClaimableError extends AppError {
  constructor() {
    super('Este benefício não está mais disponível.', 409, 'BENEFIT_NOT_CLAIMABLE');
  }
}

export class BenefitOwnershipError extends AppError {
  constructor() {
    super('Este benefício não pertence à sua conta.', 403, 'BENEFIT_NOT_OWNED');
  }
}

/**
 * Ativa um benefício: migra o usuário do plano atual para o plano do benefício
 * e marca a assinatura como ativada (activatedAt + userId). Verifica que o
 * benefício pertence ao identificador do usuário (telefone).
 *
 * PENDÊNCIA: tratamento quando o usuário JÁ é assinante Pro (s6lab). Hoje a
 * ativação sobrescreve o plano — definir regra de precedência depois.
 */
export class ActivateBenefitUseCase {
  constructor(
    private readonly repo: PartnerSubscriptionRepository,
    private readonly userRepo: UserRepository,
  ) {}

  async execute(userId: string, subscriptionId: string): Promise<{ planId: string }> {
    const sub = await this.repo.findById(subscriptionId);
    if (!sub) throw new NotFoundError('Subscription');
    if (!isClaimable(sub.status)) throw new BenefitNotClaimableError();

    // Ownership: o identificador do benefício deve bater com o telefone do user.
    if (sub.identifierType === 'phone') {
      const authUser = await getAuth().getUser(userId).catch(() => null);
      const phone = authUser?.phoneNumber ? normalizePhone(authUser.phoneNumber) : '';
      if (!phone || phone !== sub.identifier) throw new BenefitOwnershipError();
    }

    const now = new Date().toISOString();

    // Migra o plano do usuário pro plano do benefício.
    const profile = await this.userRepo.findById(userId);
    if (!profile) throw new NotFoundError('User');
    await this.userRepo.upsert({
      ...profile,
      subscriptionPlanId: sub.planId,
      subscriptionStatus: 'active',
      subscriptionStartedAt: now,
      updatedAt: now,
    });

    // Marca a assinatura como ativada por este usuário.
    await this.repo.update(subscriptionId, {
      activatedAt: now,
      userId,
      status: 'active',
    });

    return { planId: sub.planId };
  }
}
