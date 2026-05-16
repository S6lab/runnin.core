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
import { FirestoreBiometricSampleRepository } from '@modules/biometrics/infra/firestore-biometric-sample.repository';
import { IngestSamplesUseCase } from '@modules/biometrics/use-cases/ingest-samples.use-case';
import { GetSummaryUseCase } from '@modules/biometrics/use-cases/get-summary.use-case';
import { SeedTestUserUseCase } from '@modules/biometrics/use-cases/seed-test-user.use-case';

const userRepo = new FirestoreUserRepository();
const subscriptionPlanRepo = new FirestoreSubscriptionPlanRepository();
const biometricSampleRepo = new FirestoreBiometricSampleRepository();

export const container = {
  repos: {
    users: userRepo,
    subscriptionPlans: subscriptionPlanRepo,
    biometricSamples: biometricSampleRepo,
  },
  useCases: {
    getUserFeatures: new GetUserFeaturesUseCase(userRepo, subscriptionPlanRepo),
    ingestBiometricSamples: new IngestSamplesUseCase(biometricSampleRepo),
    getBiometricSummary: new GetSummaryUseCase(biometricSampleRepo),
    seedBiometricTestUser: new SeedTestUserUseCase(biometricSampleRepo),
  },
};
