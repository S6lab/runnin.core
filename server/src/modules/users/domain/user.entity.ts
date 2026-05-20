export type RunnerLevel = 'iniciante' | 'intermediario' | 'avancado';

/**
 * UserProfile fields origin:
 * - Manual: user enters value directly
 * - Device: wearable or GPS device
 * - AI: calculated/estimated by algorithm
 */
export type Gender = 'male' | 'female' | 'other' | 'na';
export type RunPeriod = 'manha' | 'tarde' | 'noite';

export interface UserProfile {
  id: string;
  name: string;
  level: RunnerLevel;
  goal: string;
  frequency: number;
  birthDate?: string;
  weight?: string;
  height?: string;
  hasWearable: boolean;
  medicalConditions: string[];
  coachVoiceId?: string;

  // Identity / demographics
  gender?: Gender;

  // Routine (from ASSESSMENT_08)
  runPeriod?: RunPeriod;
  wakeTime?: string;  // "HH:MM"
  sleepTime?: string; // "HH:MM"

  // Health metrics
  restingBpm?: number;       // FC repouso (manual or wearable)
  maxBpm?: number;           // FC máxima (manual or estimated Tanaka)

  // Coach preferences
  coachIntroSeen?: boolean;
  coachPersonality?: 'motivador' | 'tecnico' | 'sereno';
  coachMessageFrequency?: 'per_km' | 'per_2km' | 'alerts_only' | 'silent';
  coachFeedbackEnabled?: Record<string, boolean>;
  /** Quando frequency=silent, permite ainda assim alertas críticos
   *  (pace_alert, segment_pace_off, finish). Default true — assume
   *  que silencio é pra ruído, não pra risco. UI expõe toggle só
   *  quando frequency=silent (sem essa, não tem efeito). */
  allowCriticalAlertsInSilent?: boolean;

  // Run/PREP alerts
  preRunAlerts?: Record<string, boolean>;

  // Notifications
  notificationsEnabled?: Record<string, boolean>;
  dndWindow?: { start: string; end: string };

  // Units and formatting
  unitsSystem?: 'metric' | 'imperial';
  paceFormat?: 'min_per_km' | 'min_per_mi';
  timeFormat?: '24h' | '12h';

  // UI preferences
  uiSkin?: string;
  textScale?: string;

  // Plan revisions quota (revisão manual do plano atual — /request-revision)
  planRevisions?: { usedThisWeek: number; max: number; resetAt: string };

  // Plan generation/regeneration quota (gerar/descartar+gerar plano novo).
  // Distinta de planRevisions e do checkpoint (que não consomem cota aqui).
  // Novo usuário: até 2 gerações nos primeiros 7 dias (cobre erro na 1ª).
  // Depois: 1 regeneração por janela semanal.
  planGenerations?: {
    total: number;          // total de planos gerados (lifetime)
    firstPlanAt?: string;   // ISO da 1ª geração (define a janela de boas-vindas)
    usedThisWeek: number;   // consumo na janela semanal (pós-boas-vindas)
    resetAt: string;        // fim da janela semanal corrente
  };

  // Exams monthly counter
  examsCount?: number;

  // Subscription (novo modelo — fonte de verdade). Catálogo aberto: aceita ids
  // de planos de operadoras (ex: claro_basic). Resolver valida contra
  // Firestore antes de servir features.
  subscriptionPlanId?: string;
  subscriptionStatus?: 'active' | 'cancelled' | 'expired' | 'trial';
  subscriptionStartedAt?: string;
  subscriptionRenewsAt?: string;
  trialEndsAt?: string;

  // Legado (mantido pra retrocompat — get-user-features lê isso se
  // subscriptionPlanId ausente)
  premium: boolean;
  premiumUntil?: string;
  lastOnboardingAt?: string;
  operatorId?: string;
  onboarded: boolean;
  createdAt: string;
  updatedAt: string;
}

export function isPremium(profile: Pick<UserProfile, 'premium' | 'premiumUntil'> | null | undefined): boolean {
  if (!profile) return false;
  if (profile.premium) return true;
  if (!profile.premiumUntil) return false;
  return new Date(profile.premiumUntil).getTime() > Date.now();
}
