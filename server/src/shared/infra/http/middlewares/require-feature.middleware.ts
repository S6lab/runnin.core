import { Request, Response, NextFunction } from 'express';
import { container } from '@shared/container';
import { PlanFeatures } from '@modules/subscriptions/domain/plan-features';
import { ForbiddenError, UnauthorizedError } from '@shared/errors/app-error';

/**
 * Gate granular por feature. Substitui o `requirePremium` boolean.
 *
 * Uso:
 *   coachRouter.use(requireFeature('coachChat'));
 *   planRouter.post('/generate', requireFeature('generatePlan'), handler);
 *
 * Resolve o plano do user (cache 60s no repo) e checa se a feature
 * está habilitada. Resposta 403 com código FEATURE_NOT_AVAILABLE +
 * a feature exigida no body — útil pro app saber qual paywall mostrar.
 */
export const requireFeature =
  (feature: keyof PlanFeatures) =>
  async (req: Request, _res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.uid) throw new UnauthorizedError('Missing uid');
      const has = await container.useCases.getUserFeatures.hasFeature(req.uid, feature);
      if (!has) {
        throw new ForbiddenError(
          `Feature "${feature}" não está disponível no seu plano.`,
        );
      }
      next();
    } catch (err) {
      next(err);
    }
  };
