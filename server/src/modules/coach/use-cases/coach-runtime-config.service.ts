import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { logger } from '@shared/logger/logger';

/**
 * Config dinâmica do Coach Live durante a corrida (lados app + server).
 * Salvo em Firestore `app_config/coach_runtime` — editável via admin sem
 * deploy de Dart. Cache 60s server-side.
 *
 * App fetcha via GET /v1/coach/runtime-config no boot da Home, cacheia 1h
 * em Hive, fallback hardcoded se 404/timeout.
 */
export interface CoachRuntimeConfig {
  /** Distância (m) entre cues de presença ao vivo. */
  checkInDistanceM: number;
  /** Tempo idle (s) sem coach falar antes de disparar check_in por tempo. */
  checkInIdleSeconds: number;
  /** Idade (min) da sessão Live antes de rotação preventiva. */
  rotationAgeMinutes: number;
  /** Cap de tentativas de reconnect antes de desistir. */
  maxReconnectAttempts: number;
  /** Cooldowns (s) por tipo de evento. */
  cooldownsBy: {
    pace_alert: number;
    segment_pace_off: number;
    high_bpm: number;
    segment_end: number;
  };
  /** Throttle (ms) entre sends drenados do pendingSends queue. */
  pendingSendsThrottleMs: number;
  /** Cap de cues em fila simultânea. */
  pendingSendsMaxQueue: number;
  /** Janela (ms) após start em que cues são suprimidos (saudação inicial). */
  suppressCuesGreetingMs: number;
}

export const DEFAULT_COACH_RUNTIME_CONFIG: CoachRuntimeConfig = {
  checkInDistanceM: 500,
  checkInIdleSeconds: 240,
  rotationAgeMinutes: 4,
  maxReconnectAttempts: 10,
  cooldownsBy: {
    pace_alert: 60,
    segment_pace_off: 60,
    high_bpm: 90,
    segment_end: 999_999,
  },
  pendingSendsThrottleMs: 2_000,
  pendingSendsMaxQueue: 3,
  suppressCuesGreetingMs: 12_000,
};

const CACHE_TTL_MS = 60_000;
const DOC_PATH = { col: 'app_config', doc: 'coach_runtime' };
let _cached: { value: CoachRuntimeConfig; loadedAt: number } | null = null;

/**
 * Lê config vigente (Firestore override sobre default). Cache 60s.
 * Falha silenciosa devolve default — coach não pode quebrar por config
 * indisponível.
 */
export async function getCoachRuntimeConfig(): Promise<CoachRuntimeConfig> {
  const now = Date.now();
  if (_cached && now - _cached.loadedAt < CACHE_TTL_MS) return _cached.value;
  try {
    const snap = await getFirestore().collection(DOC_PATH.col).doc(DOC_PATH.doc).get();
    const override = snap.exists ? (snap.data() as Partial<CoachRuntimeConfig> | undefined) : null;
    const value = override
      ? { ...DEFAULT_COACH_RUNTIME_CONFIG, ...override, cooldownsBy: { ...DEFAULT_COACH_RUNTIME_CONFIG.cooldownsBy, ...(override.cooldownsBy ?? {}) } }
      : DEFAULT_COACH_RUNTIME_CONFIG;
    _cached = { value, loadedAt: now };
    return value;
  } catch (err) {
    logger.warn('coach.runtime_config.load_failed', { err: String(err) });
    return _cached?.value ?? DEFAULT_COACH_RUNTIME_CONFIG;
  }
}

export function invalidateCoachRuntimeConfigCache(): void {
  _cached = null;
}
