/**
 * Container DI manual — singletons compartilhados entre controllers + middlewares.
 *
 * Não usamos framework de DI (Inversify/NestJS) porque o projeto é compacto
 * e singletons importados resolvem 100% do uso. Quando precisarmos de
 * testes unitários, controllers podem aceitar repos via param ou usar
 * `jest.mock('@shared/container')`.
 */
import { FirestoreUserRepository } from '@modules/users/infra/firestore-user.repository';
import { FirestoreSubscriptionPlanRepository } from '@modules/subscriptions/infra/firestore-subscription-plan.repository';
import { GetUserFeaturesUseCase } from '@modules/subscriptions/use-cases/get-user-features.use-case';

const userRepo = new FirestoreUserRepository();
const subscriptionPlanRepo = new FirestoreSubscriptionPlanRepository();

export const container = {
  repos: {
    users: userRepo,
    subscriptionPlans: subscriptionPlanRepo,
  },
  useCases: {
    getUserFeatures: new GetUserFeaturesUseCase(userRepo, subscriptionPlanRepo),
  },
};
