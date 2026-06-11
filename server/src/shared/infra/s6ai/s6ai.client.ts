import { logger } from '@shared/logger/logger';
import { mintIdToken } from './s6-proxy';

/**
 * Cliente HTTP do microsserviço s6-ai (IA: geração/revisão de plano +
 * Gemini Live). Auth service-to-service via X-Internal-Token — rotas de
 * plano também são chamadas por cron (weekly proposals), onde não existe
 * token de usuário; o userId vai no payload só pra atribuição de llm_usage.
 *
 * Env:
 *  - S6_AI_URL    ex: https://runnin-s6-ai-staging-xxx.run.app
 *  - S6_INTERNAL_TOKEN  mesmo valor configurado no s6-ai (Secret Manager)
 */

export interface S6RawPlanSegment {
  kmStart: number;
  kmEnd: number;
  phase: string;
  targetPace?: string;
  durationMin?: number;
  instruction: string;
}

export interface S6RawPlanSession {
  dayOfWeek: number;
  type: string;
  distanceKm: number;
  targetPace?: string;
  durationMin?: number;
  hydrationLiters?: number;
  nutritionPre?: string;
  nutritionPost?: string;
  executionSegments?: S6RawPlanSegment[];
  notes: string;
}

export interface S6RawPlanWeek {
  weekNumber: number;
  sessions: S6RawPlanSession[];
  restDayTips?: Array<{
    dayOfWeek: number;
    hydrationLiters?: number;
    nutrition?: string;
    focus?: string;
  }>;
}

export interface S6GenerateWeeksRequest {
  userId: string;
  profile: unknown;
  biometricSummary?: unknown;
  input: {
    goal: string;
    level: string;
    frequency: number;
    weeksCount: number;
    startDate: string;
    levelHint?: string | null;
    currentWeeklyKm?: number | null;
    currentPaceMinKm?: string | null;
    capacityDistanceKm?: number | null;
    availableDays?: number[] | null;
    goalKind?: 'flow' | 'race';
    flowSubgoal?: 'start' | 'improve' | 'injury_return' | 'postpartum';
    raceDistanceKm?: number;
    raceMode?: 'complete' | 'improve_pace';
    targetPaceMinKm?: string;
    windowMode?: 'aggressive' | 'feasible' | 'safe';
    longRunDayOfWeek?: number;
    longRunMaxMinutes?: number;
    raceDate?: string;
  };
}

export interface S6GenerateWeeksResponse {
  weeks: S6RawPlanWeek[];
  countMismatch: boolean;
  meta: { promptVersion: string; promptSource: string };
}

export interface S6RevisePlanRequest {
  userId: string;
  profile: unknown;
  plan: {
    goal: string;
    level: string;
    weeksCount: number;
    weeks: unknown[];
    raceDate?: string | null;
    raceDayOfWeek?: number | null;
  };
  revision: { type: string; subOption?: string; freeText?: string };
  currentWeekNumber: number;
}

export interface S6RevisePlanResponse {
  coachExplanation: string;
  newWeeks: Array<{
    weekNumber: number;
    sessions: Array<{
      dayOfWeek: number;
      type: string;
      distanceKm: number;
      targetPace?: string;
      notes: string;
    }>;
    focus?: string;
    narrative?: string;
  }>;
  meta: { promptVersion: string; promptSource: string };
}

export interface S6LiveSessionContext {
  userId: string;
  persona?: string | null;
  voice?: string;
  locale?: string;
  profileSnippet?: string;
  sessionBriefing?: string;
  sessionNotes?: string | null;
  segments?: Array<{
    kmStart: number;
    kmEnd: number;
    phase: string;
    targetPace?: string | null;
    instruction?: string | null;
  }>;
  weather?: {
    temperatureC?: number | null;
    humidityPercent?: number | null;
    windKmh?: number | null;
  } | null;
  prefs?: {
    freq: 'high' | 'normal' | 'per_2km' | 'alerts_only' | 'silent';
    dnd: boolean;
    allowCriticalAlertsInSilent: boolean;
  };
  athleteName?: string | null;
}

export interface S6CreateLiveSessionResponse {
  sessionId: string;
  wsUrl: string;
  expiresAt: string;
}

export class S6AiError extends Error {
  constructor(
    message: string,
    public readonly status: number,
    public readonly body: string,
  ) {
    super(message);
    this.name = 'S6AiError';
  }
}

export class S6AiClient {
  private readonly baseUrl: string;
  private readonly token: string;

  constructor() {
    this.baseUrl = (process.env['S6_AI_URL'] ?? '').trim().replace(/\/$/, '');
    this.token = (process.env['S6_INTERNAL_TOKEN'] ?? '').trim();
  }

  async generatePlanWeeks(req: S6GenerateWeeksRequest): Promise<S6GenerateWeeksResponse> {
    return this._post<S6GenerateWeeksResponse>('/v1/plan/generate', req);
  }

  async revisePlan(req: S6RevisePlanRequest): Promise<S6RevisePlanResponse> {
    return this._post<S6RevisePlanResponse>('/v1/plan/revise', req);
  }

  async createLiveSession(context: S6LiveSessionContext): Promise<S6CreateLiveSessionResponse> {
    return this._post<S6CreateLiveSessionResponse>('/v1/live/sessions', { context });
  }

  /**
   * Fan-out do admin: o editor de prompts grava em app_config/prompts e o
   * s6-ai tem cache 60s — sem invalidar lá, prompt velho serve por 1min.
   * Best-effort: falha não quebra o fluxo do admin.
   */
  async invalidatePromptCache(): Promise<void> {
    try {
      await this._post<{ ok: boolean }>('/v1/internal/prompts/invalidate-cache', {});
    } catch (err) {
      logger.warn('s6ai.invalidate_prompt_cache_failed', { err: String(err) });
    }
  }

  private async _post<T>(path: string, body: unknown): Promise<T> {
    if (!this.baseUrl) {
      throw new Error('S6_AI_URL not configured');
    }
    const startedAt = Date.now();
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'X-Internal-Token': this.token,
    };
    // s6-ai staging roda SEM allUsers (IAM travado em conta Editor) —
    // a invocação Cloud Run exige ID token do runtime SA (deploy@/Editor
    // tem run.routes.invoke). Header dedicado preserva o X-Internal-Token.
    const idToken = await mintIdToken(this.baseUrl);
    if (idToken) headers['X-Serverless-Authorization'] = `Bearer ${idToken}`;
    const res = await fetch(`${this.baseUrl}${path}`, {
      method: 'POST',
      headers,
      body: JSON.stringify(body),
    });
    const ms = Date.now() - startedAt;
    if (!res.ok) {
      const text = await res.text().catch(() => '');
      logger.warn('s6ai.request_failed', { path, status: res.status, ms, body: text.slice(0, 300) });
      throw new S6AiError(`s6-ai ${path} failed with ${res.status}`, res.status, text);
    }
    logger.info('s6ai.request_ok', { path, ms });
    return (await res.json()) as T;
  }
}
