/**
 * Registries estáticos do admin: momentos do Coach.AI, jobs do Cloud
 * Scheduler, catálogo de planos de assinatura, snapshot das constantes de
 * regra do plano, registry dos promptIds disponíveis.
 *
 * Esses dados são (a) fontes de verdade no server (não em Firestore — não
 * são overrideáveis runtime), (b) consumidos read-only pelo admin do app.
 *
 * **Importante**: ao mexer em `infra/scheduler.tf`, atualizar `CRONS_REGISTRY`
 * abaixo junto. Sem isso o admin mostra um valor que não corresponde ao GCP.
 */

import {
  AGE_RESTRICTION_THRESHOLDS,
  IMPROVE_PACE_BYPASS_BY_LEVEL,
  MAX_KM_PER_SESSION,
  MIN_FREQ_BY_PROFILE_DISTANCE,
  PACE_IMPROVEMENT_CEILING_PCT,
  PEAK_WEEKLY_KM,
  RACE_WINDOWS,
  RAMP_BASE_FLOOR_KM,
  SERIOUS_MEDICAL_KEYWORDS,
  WEEKLY_RAMP_RATE,
  WINDOW_RESTRICTION_BY_PROFILE,
} from '@modules/plans/use-cases/plan-windows.constants';

// ─── Coach.AI moments ────────────────────────────────────────────────────

export interface CoachMoment {
  id: number;
  title: string;
  description: string;
  model: string;
  ragEnabled: boolean;
  promptIds: string[];
}

export const COACH_AI_MOMENTS: CoachMoment[] = [
  {
    id: 1,
    title: 'Indexação do conhecimento',
    description: 'Embedding de chunks da base (running-knowledge + uploads admin) pra retrieval semântico.',
    model: 'gemini-embedding-001',
    ragEnabled: true,
    promptIds: [],
  },
  {
    id: 2,
    title: 'Geração de Plano + Ajuste',
    description: 'Plan-init na criação; plan-revision no checkpoint semanal de domingo (auto-apply).',
    model: 'gemini-3.1-pro-preview',
    ragEnabled: true,
    promptIds: ['plan-init', 'plan-revision'],
  },
  {
    id: 3,
    title: 'Operação de Texto',
    description: 'Relatórios pós-corrida (curto e enriched), análises de período, semanal, chat.',
    model: 'gemini-3.5-flash',
    ragEnabled: true,
    promptIds: ['post-run-report', 'post-run-report-enriched', 'weekly-report', 'period-analysis', 'coach-chat', 'live-coach'],
  },
  {
    id: 4,
    title: 'Multimodal / Exame',
    description: 'Análise estruturada de exames (FC, lactato, VO2) com schema JSON.',
    model: 'gemini-3.5-flash',
    ragEnabled: true,
    promptIds: ['exam-analysis'],
  },
  {
    id: 5,
    title: 'Voz ao Vivo',
    description: 'Coach falando durante a corrida; latência crítica, sem RAG.',
    model: 'gemini-2.5-flash-native-audio',
    ragEnabled: false,
    promptIds: ['live-voice'],
  },
];

// ─── Cron jobs (espelha infra/scheduler.tf) ──────────────────────────────

export interface CronJobEntry {
  name: string;
  description: string;
  schedule: string;       // cron expression
  humanSchedule: string;  // ex: "Domingo 23:00 BRT"
  timezone: string;
  env: 'staging' | 'prod';
  httpTarget: string;
}

export const CRONS_REGISTRY: CronJobEntry[] = [
  {
    name: 'weekly-plan-proposals',
    description: 'Checkpoint semanal automático: revisa plano + libera próxima semana com detalhe.',
    schedule: '0 23 * * 0',
    humanSchedule: 'Domingo 23:00 BRT',
    timezone: 'America/Sao_Paulo',
    env: 'staging',
    httpTarget: '/v1/admin/cron/weekly-proposals',
  },
  {
    name: 'weekly-plan-proposals-prod',
    description: 'Checkpoint semanal automático (PROD).',
    schedule: '0 23 * * 0',
    humanSchedule: 'Domingo 23:00 BRT',
    timezone: 'America/Sao_Paulo',
    env: 'prod',
    httpTarget: '/v1/admin/cron/weekly-proposals',
  },
  {
    name: 'runnin-daily-push',
    description: 'Notificações in-app + push motivacional diários.',
    schedule: '0 8 * * *',
    humanSchedule: 'Diário 08:00 BRT',
    timezone: 'America/Sao_Paulo',
    env: 'staging',
    httpTarget: '/v1/notifications/ensure-daily',
  },
  {
    name: 'runnin-daily-push-prod',
    description: 'Notificações in-app + push motivacional diários (PROD).',
    schedule: '0 8 * * *',
    humanSchedule: 'Diário 08:00 BRT',
    timezone: 'America/Sao_Paulo',
    env: 'prod',
    httpTarget: '/v1/notifications/ensure-daily',
  },
];

// ─── Subscription plans catalog ──────────────────────────────────────────

export interface SubscriptionPlanOption {
  id: string;
  label: string;
  operatorId?: string;
  isDefault?: boolean;
  description?: string;
}

export const PLANS_CATALOG: SubscriptionPlanOption[] = [
  { id: 'freemium', label: 'Freemium', isDefault: true, description: 'Plano grátis — features limitadas, sem checkpoint semanal automático.' },
  { id: 'pro_s6lab', label: 'Pro · s6lab', operatorId: 's6lab', description: 'Premium completo da S6lab.' },
  { id: 'claro_basic', label: 'Claro Basic · claro', operatorId: 'claro', description: 'Premium parceria Claro (básico).' },
];

// ─── Prompts registry (espelha DEFAULTS_BY_ID) ───────────────────────────

export interface PromptRegistryEntry {
  id: string;
  label: string;
  category: 'plan' | 'live' | 'report' | 'chat' | 'exam';
  deprecated?: boolean;
}

export const PROMPTS_REGISTRY: PromptRegistryEntry[] = [
  { id: 'plan-init', label: 'Geração inicial do plano', category: 'plan' },
  { id: 'plan-revision', label: 'Revisão semanal do plano', category: 'plan' },
  { id: 'live-coach', label: 'Coach ao vivo (texto)', category: 'live' },
  { id: 'live-voice', label: 'Coach ao vivo (voz)', category: 'live' },
  { id: 'post-run-report', label: 'Relatório pós-corrida (curto)', category: 'report' },
  { id: 'post-run-report-enriched', label: 'Relatório pós-corrida (enriched/JSON)', category: 'report' },
  { id: 'period-analysis', label: 'Análise de período', category: 'report' },
  { id: 'weekly-report', label: 'Relatório semanal', category: 'report', deprecated: true },
  { id: 'coach-chat', label: 'Chat livre com o coach', category: 'chat' },
  { id: 'exam-analysis', label: 'Análise de exame', category: 'exam' },
];

// ─── Plan rules snapshot ─────────────────────────────────────────────────

export interface PlanRulesSnapshot {
  raceWindows: typeof RACE_WINDOWS;
  peakWeeklyKm: typeof PEAK_WEEKLY_KM;
  weeklyRampRate: typeof WEEKLY_RAMP_RATE;
  rampBaseFloorKm: typeof RAMP_BASE_FLOOR_KM;
  minFreqByProfileDistance: typeof MIN_FREQ_BY_PROFILE_DISTANCE;
  windowRestrictionByProfile: typeof WINDOW_RESTRICTION_BY_PROFILE;
  improvePaceBypassByLevel: typeof IMPROVE_PACE_BYPASS_BY_LEVEL;
  maxKmPerSession: typeof MAX_KM_PER_SESSION;
  seriousMedicalKeywords: typeof SERIOUS_MEDICAL_KEYWORDS;
  ageRestrictionThresholds: typeof AGE_RESTRICTION_THRESHOLDS;
  paceImprovementCeilingPct: typeof PACE_IMPROVEMENT_CEILING_PCT;
}

export function getPlanRulesSnapshot(): PlanRulesSnapshot {
  return {
    raceWindows: RACE_WINDOWS,
    peakWeeklyKm: PEAK_WEEKLY_KM,
    weeklyRampRate: WEEKLY_RAMP_RATE,
    rampBaseFloorKm: RAMP_BASE_FLOOR_KM,
    minFreqByProfileDistance: MIN_FREQ_BY_PROFILE_DISTANCE,
    windowRestrictionByProfile: WINDOW_RESTRICTION_BY_PROFILE,
    improvePaceBypassByLevel: IMPROVE_PACE_BYPASS_BY_LEVEL,
    maxKmPerSession: MAX_KM_PER_SESSION,
    seriousMedicalKeywords: SERIOUS_MEDICAL_KEYWORDS,
    ageRestrictionThresholds: AGE_RESTRICTION_THRESHOLDS,
    paceImprovementCeilingPct: PACE_IMPROVEMENT_CEILING_PCT,
  };
}
