import { SubscriptionPlan } from './subscription-plan.entity';
import { PlanFeatures, PlanLimits } from './plan-features';

const NOW = new Date(0).toISOString(); // seed timestamp fixo (idempotência)

export const FREEMIUM_FEATURES: PlanFeatures = {
  runTracking: true,
  freeRun: true,
  plannedRun: false,
  generatePlan: false,
  weeklyReports: false,
  planRevisions: false,
  coachChat: false,
  coachLive: false,
  coachVoiceDuringRun: false,
  healthZones: false,
  examsOCR: false,
  wearableSync: false,
  shareWithOverlay: true,
  historyExport: false,
};

export const PRO_FEATURES: PlanFeatures = {
  runTracking: true,
  freeRun: true,
  plannedRun: true,
  generatePlan: true,
  weeklyReports: true,
  planRevisions: true,
  coachChat: true,
  coachLive: true,
  coachVoiceDuringRun: true,
  healthZones: true,
  examsOCR: true,
  wearableSync: true,
  shareWithOverlay: true,
  historyExport: true,
};

export const FREEMIUM_LIMITS: PlanLimits = {
  plansPerMonth: 0,
  examsPerMonth: 0,
  coachMessagesPerDay: 0,
  weeklyReportsPerMonth: 0,
};

export const PRO_LIMITS: PlanLimits = {
  plansPerMonth: 1,            // 1 plano novo + revisões semanais
  examsPerMonth: 5,
  coachMessagesPerDay: 50,
  weeklyReportsPerMonth: 4,
};

export const FREEMIUM_PLAN: SubscriptionPlan = {
  id: 'freemium',
  name: 'Gratuito',
  priceLabel: 'Grátis',
  periodLabel: '',
  features: FREEMIUM_FEATURES,
  limits: FREEMIUM_LIMITS,
  active: true,
  createdAt: NOW,
  updatedAt: NOW,
};

export const PRO_PLAN: SubscriptionPlan = {
  id: 'pro',
  name: 'Pro',
  priceLabel: 'R$ 19,90',
  periodLabel: '/mês',
  features: PRO_FEATURES,
  limits: PRO_LIMITS,
  active: true,
  createdAt: NOW,
  updatedAt: NOW,
};

export const DEFAULT_PLANS: SubscriptionPlan[] = [FREEMIUM_PLAN, PRO_PLAN];
