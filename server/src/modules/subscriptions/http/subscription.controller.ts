import { Request, Response, NextFunction } from 'express';
import { container } from '@shared/container';
import { DEFAULT_PLANS } from '../domain/defaults';

/**
 * GET /v1/subscriptions/plans — público (catálogo de planos pra paywall)
 */
export async function listPlans(_req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const plans = await container.repos.subscriptionPlans.listAll();
    res.json({ plans });
  } catch (err) {
    next(err);
  }
}

/**
 * GET /v1/subscriptions/me — auth (plano atual do user + features)
 */
export async function getMySubscription(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const plan = await container.useCases.getUserFeatures.getPlan(req.uid);
    const planId = await container.useCases.getUserFeatures.resolvePlanId(req.uid);
    res.json({ planId, plan });
  } catch (err) {
    next(err);
  }
}

/**
 * POST /v1/admin/subscriptions/seed — idempotente (popula os 2 planos default)
 * Útil em primeiro deploy ou pra restaurar planos sobrescritos.
 */
export async function seedPlans(_req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    for (const plan of DEFAULT_PLANS) {
      await container.repos.subscriptionPlans.upsert(plan);
    }
    res.json({ ok: true, seeded: DEFAULT_PLANS.map((p) => p.id) });
  } catch (err) {
    next(err);
  }
}
