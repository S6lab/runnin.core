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
import { FirestorePartnerSubscriptionRepository } from '@modules/subscriptions/infra/firestore-partner-subscription.repository';
import { GetUserFeaturesUseCase } from '@modules/subscriptions/use-cases/get-user-features.use-case';
import { LookupBenefitsUseCase } from '@modules/subscriptions/use-cases/lookup-benefits.use-case';
import { ActivateBenefitUseCase } from '@modules/subscriptions/use-cases/activate-benefit.use-case';
import { FirestoreBiometricSampleRepository } from '@modules/biometrics/infra/firestore-biometric-sample.repository';
import { IngestSamplesUseCase } from '@modules/biometrics/use-cases/ingest-samples.use-case';
import { GetSummaryUseCase } from '@modules/biometrics/use-cases/get-summary.use-case';
import { SeedTestUserUseCase } from '@modules/biometrics/use-cases/seed-test-user.use-case';
import { FirestorePlanRepository } from '@modules/plans/infra/firestore-plan.repository';
import { FirestorePlanRevisionRepository } from '@modules/plans/infra/firestore-plan-revision.repository';
import { FirestorePlanCheckpointRepository } from '@modules/plans/infra/firestore-plan-checkpoint.repository';
import { FirestoreRunRepository } from '@modules/runs/infra/firestore-run.repository';
import { FirestoreNotificationRepository } from '@modules/notifications/infra/firestore-notification.repository';
import { CreateNotificationUseCase } from '@modules/notifications/domain/use-cases/create-notification.use-case';
import { RequestRevisionUseCase } from '@modules/plans/use-cases/request-revision.use-case';
import { AdaptPlanUseCase } from '@modules/plans/use-cases/adapt-plan.use-case';
import { LlmCheckpointAnalysisStrategy } from '@modules/plans/use-cases/llm-checkpoint-analysis.strategy';
import { ProposeCheckpointUseCase } from '@modules/plans/use-cases/propose-checkpoint.use-case';
import { ResolveProposalUseCase } from '@modules/plans/use-cases/resolve-proposal.use-case';
import { RunWeeklyProposalsUseCase } from '@modules/plans/use-cases/run-weekly-proposals.use-case';

const userRepo = new FirestoreUserRepository();
const subscriptionPlanRepo = new FirestoreSubscriptionPlanRepository();
const partnerSubscriptionRepo = new FirestorePartnerSubscriptionRepository();
const biometricSampleRepo = new FirestoreBiometricSampleRepository();
const planRepo = new FirestorePlanRepository();
const planRevisionRepo = new FirestorePlanRevisionRepository();
const planCheckpointRepo = new FirestorePlanCheckpointRepository();
const runRepo = new FirestoreRunRepository();
const notificationRepo = new FirestoreNotificationRepository();
const createNotification = new CreateNotificationUseCase(notificationRepo);
const requestRevision = new RequestRevisionUseCase(planRepo, planRevisionRepo, userRepo);
const adaptPlan = new AdaptPlanUseCase(planRepo, runRepo, requestRevision, userRepo, planRevisionRepo);
const checkpointAnalysisStrategy = new LlmCheckpointAnalysisStrategy();
const proposeCheckpoint = new ProposeCheckpointUseCase(
  planRepo,
  planCheckpointRepo,
  planRevisionRepo,
  runRepo,
  checkpointAnalysisStrategy,
  createNotification,
);
const resolveProposal = new ResolveProposalUseCase(planRepo, planCheckpointRepo, planRevisionRepo);
const runWeeklyProposals = new RunWeeklyProposalsUseCase(
  userRepo,
  planRepo,
  runRepo,
  proposeCheckpoint,
);

export const container = {
  repos: {
    users: userRepo,
    subscriptionPlans: subscriptionPlanRepo,
    partnerSubscriptions: partnerSubscriptionRepo,
    biometricSamples: biometricSampleRepo,
    plans: planRepo,
    planRevisions: planRevisionRepo,
    planCheckpoints: planCheckpointRepo,
    runs: runRepo,
    notifications: notificationRepo,
  },
  useCases: {
    getUserFeatures: new GetUserFeaturesUseCase(userRepo, subscriptionPlanRepo),
    lookupBenefits: new LookupBenefitsUseCase(partnerSubscriptionRepo, subscriptionPlanRepo),
    activateBenefit: new ActivateBenefitUseCase(partnerSubscriptionRepo, userRepo, subscriptionPlanRepo),
    ingestBiometricSamples: new IngestSamplesUseCase(biometricSampleRepo),
    getBiometricSummary: new GetSummaryUseCase(biometricSampleRepo),
    seedBiometricTestUser: new SeedTestUserUseCase(biometricSampleRepo),
    requestRevision,
    adaptPlan,
    createNotification,
    proposeCheckpoint,
    resolveProposal,
    runWeeklyProposals,
  },
};
