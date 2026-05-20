import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { v4 as uuid } from 'uuid';
import { container } from '@shared/container';
import {
  detectIdentifier,
  PartnerSubscription,
} from '../domain/partner-subscription.entity';

/**
 * GET /v1/subscriptions/benefits — benefícios (assinaturas de parceiro) do
 * usuário logado, resolvidos pelo identificador (telefone). Silencioso: [] se
 * não houver.
 */
export async function getBenefits(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const items = await container.useCases.lookupBenefits.execute(req.uid);
    res.json({ items });
  } catch (err) {
    next(err);
  }
}

/**
 * POST /v1/subscriptions/benefits/:id/activate — ativa o benefício: migra o
 * usuário pro plano do benefício e marca a assinatura como ativada.
 */
export async function activateBenefit(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const id = req.params['id'] as string;
    const result = await container.useCases.activateBenefit.execute(req.uid, id);
    res.json(result);
  } catch (err) {
    next(err);
  }
}

const IngestBenefitSchema = z.object({
  // ID enviado pelo parceiro (doc id). Se ausente, gera um.
  id: z.string().min(1).optional(),
  identifier: z.string().min(3),
  provider: z.string().min(1),
  // ID do serviço junto ao parceiro — o plano é resolvido por ele na ativação.
  serviceId: z.string().min(1),
  status: z.enum(['active', 'cancelled', 'reactivated', 'pending']).default('active'),
  cancelledAt: z.string().optional(),
  reactivatedAt: z.string().optional(),
});

/**
 * POST /v1/subscriptions/benefits — INGESTÃO (stub). Cria/atualiza uma
 * assinatura de parceiro na collection `subscriptions`. Detecta o tipo do
 * identificador automaticamente.
 *
 * PENDÊNCIA: em produção isto deve ser um webhook autenticado por parceiro
 * (assinatura/HMAC), não um endpoint de usuário. Mantido auth simples pra
 * bootstrap/testes em staging.
 */
export async function ingestBenefit(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const body = IngestBenefitSchema.parse(req.body);
    const { type, normalized } = detectIdentifier(body.identifier);
    const now = new Date().toISOString();
    const sub: PartnerSubscription = {
      id: body.id ?? uuid(),
      identifier: normalized,
      identifierType: type,
      provider: body.provider,
      serviceId: body.serviceId,
      status: body.status,
      createdAt: now,
      cancelledAt: body.cancelledAt,
      reactivatedAt: body.reactivatedAt,
    };
    await container.repos.partnerSubscriptions.upsert(sub);
    res.status(201).json(sub);
  } catch (err) {
    next(err);
  }
}
