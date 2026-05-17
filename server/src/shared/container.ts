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
import { FirestorePlanRepository } from '@modules/plans/infra/firestore-plan.repository';
import { FirestorePlanRevisionRepository } from '@modules/plans/infra/firestore-plan-revision.repository';
import { FirestoreRunRepository } from '@modules/runs/infra/firestore-run.repository';
import { RequestRevisionUseCase } from '@modules/plans/use-cases/request-revision.use-case';
import { AdaptPlanUseCase } from '@modules/plans/use-cases/adapt-plan.use-case';

const userRepo = new FirestoreUserRepository();
const subscriptionPlanRepo = new FirestoreSubscriptionPlanRepository();
const biometricSampleRepo = new FirestoreBiometricSampleRepository();
const planRepo = new FirestorePlanRepository();
const planRevisionRepo = new FirestorePlanRevisionRepository();
const runRepo = new FirestoreRunRepository();
const requestRevision = new RequestRevisionUseCase(planRepo, planRevisionRepo, userRepo);
const adaptPlan = new AdaptPlanUseCase(planRepo, runRepo, requestRevision, userRepo, planRevisionRepo);

export const container = {
  repos: {
    users: userRepo,
    subscriptionPlans: subscriptionPlanRepo,
    biometricSamples: biometricSampleRepo,
    plans: planRepo,
    planRevisions: planRevisionRepo,
    runs: runRepo,
  },
  useCases: {
    getUserFeatures: new GetUserFeaturesUseCase(userRepo, subscriptionPlanRepo),
    ingestBiometricSamples: new IngestSamplesUseCase(biometricSampleRepo),
    getBiometricSummary: new GetSummaryUseCase(biometricSampleRepo),
    seedBiometricTestUser: new SeedTestUserUseCase(biometricSampleRepo),
    requestRevision,
    adaptPlan,
  },
};
