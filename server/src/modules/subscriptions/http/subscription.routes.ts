import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { listPlans, getMySubscription, seedPlans } from './subscription.controller';

export const subscriptionRouter = Router();

// Público — paywall lê pra renderizar opções
subscriptionRouter.get('/plans', listPlans);

// Auth — app sabe quais features o user tem
subscriptionRouter.get('/me', authMiddleware, getMySubscription);

// Admin seed (idempotente). Sem requireAdmin por enquanto pra facilitar bootstrap
// inicial; pode adicionar depois com `requireAdmin` middleware.
subscriptionRouter.post('/seed', seedPlans);
