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
  /**
   * Doc id = Firebase Auth uid. Source-of-truth pra lookup; é o que vai como
   * `req.uid` em todas as rotas autenticadas.
   */
  id: string;
  /**
   * Redundância intencional do uid pra trace cross-system: quando exportamos
   * pra analytics / BigQuery, o `id` pode virar `userId` em alguns sinks
   * mas o `authId` permanece imutável como referência ao Firebase Auth.
   * Setado em `provisionUser` a partir do uid; igual ao `id` por design.
   */
  authId: string;
  /**
   * Email do Firebase Auth (admin.auth().getUser(uid).email). Capturado no
   * provision; null quando o user assinou só com telefone (Brazil-friendly).
   * Pelo menos UM de email/phone deve estar presente (garantido pelo Auth).
   */
  email?: string;
  /**
   * Telefone E.164 do Firebase Auth (admin.auth().getUser(uid).phoneNumber).
   * Null quando o user assinou só com email/social. Pelo menos um de
   * email/phone deve estar presente.
   */
  phone?: string;
  name: string;
  level: RunnerLevel;
  goal: string;
  frequency: number;
  /**
   * Dias da semana em que o atleta pode treinar (1=seg…7=dom). Preenchido na
   * jornada de criação do plano (tela "dias + frequência"). A IA escolhe os
   * melhores dias se `frequency < availableDays.length`. Array vazio/ausente
   * = sem restrição (IA escolhe livremente).
   */
  availableDays?: number[];

  // ─── Inputs do assessment de criação do plano ───────────────────────────
  // Persistidos aqui pra auditoria + reuso em re-geração. Atualizados em
  // GeneratePlanUseCase quando o user gera/regera um plano. Espelham o
  // payload de /plans/generate; nem todos são obrigatórios.
  /** Volume semanal atual auto-reportado (km/sem). */
  currentWeeklyKm?: number;
  /** Pace confortável auto-reportado (M:SS/km). */
  currentPaceMinKm?: string;
  /** Distância confortável recente auto-reportada (km). */
  capacityDistanceKm?: number;
  /** Resultado da última corrida de AVALIAÇÃO (assessment run) — capacidade
   *  MEDIDA, não declarada. Persistido pelo complete-run quando a corrida
   *  tem `assessmentTargetKm`. Prevalece sobre o auto-reportado no prefill
   *  do wizard e dá provenance "medido" no prompt de geração de plano.
   *  Parcial (<50% do alvo) NÃO sobrescreve capacity/pace acima — só este
   *  registro, com completedKm real. */
  lastAssessment?: {
    runId: string;
    at: string; // ISO
    targetKm: number;
    completedKm: number;
    paceMinKm: string; // M:SS
    avgBpm?: number;
  };
  /** Matiz fino do nível "iniciante" (jornada nova). */
  levelHint?: 'nunca_corri' | 'esporadico' | 'iniciante_freq';
  /** Tipo de objetivo do plano atual: 'flow' (sem prova) ou 'race' (meta). */
  goalKind?: 'flow' | 'race';
  /** Sub-meta dentro de FLOW. */
  flowSubgoal?: 'start' | 'improve' | 'injury_return' | 'postpartum';
  /** Distância da prova (5, 10, 21, 42) quando goalKind=race. */
  raceDistanceKm?: 5 | 10 | 21 | 42;
  /** Modo da meta race: completar ou bater pace alvo. */
  raceMode?: 'complete' | 'improve_pace';
  /** Pace alvo M:SS/km (só raceMode=improve_pace). */
  targetPaceMinKm?: string;
  /** Data da prova/alvo (ISO YYYY-MM-DD). */
  raceDate?: string;
  /** Dia preferido pro long run (1=seg…7=dom). */
  longRunDayOfWeek?: number;
  /** Tempo máximo disponível pro long run (minutos). */
  longRunMaxMinutes?: number;
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
  coachPersonality?: 'motivador' | 'tecnico';
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

  // Localização (resolvida por reverse geocoding da posição GPS do device).
  // Preenchida pelo POST /users/me/location quando o app abre a home com
  // permissão de localização concedida. Usada na home (header) e nos chips
  // de clima + injetada no contexto do live coach.
  city?: string;
  lastKnownLat?: number;
  lastKnownLng?: number;
  lastLocationAt?: string;

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
