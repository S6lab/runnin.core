import { z } from 'zod';

/**
 * Os 8 eventos do cue system (redução dos 16 legados — vast-hearth).
 * Prioridades: P0 interrompe fala ativa; P1 espera P0 e preempta P2/P3
 * na fila; P2 espera P0+P1 e descarta P3 pendente; P3 só entra com a
 * fila vazia e ociosa.
 */
export const CUE_EVENTS = [
  'start',
  'half_km',
  'km_reached',
  'bpm_alert',
  'pace_alert',
  'goal_reached',
  'finish',
  'no_movement',
] as const;

export type CueEvent = (typeof CUE_EVENTS)[number];

export type CuePriority = 0 | 1 | 2 | 3;

export const CUE_PRIORITY: Record<CueEvent, CuePriority> = {
  bpm_alert: 0,
  pace_alert: 1,
  goal_reached: 1,
  finish: 1,
  start: 2,
  km_reached: 2,
  half_km: 3,
  no_movement: 3,
};

/** Cooldown por evento em ms. Ausente = sem cooldown (dedup por bucket/one-shot). */
export const CUE_COOLDOWN_MS: Partial<Record<CueEvent, number>> = {
  bpm_alert: 60_000,
  pace_alert: 30_000,
  no_movement: 60_000,
};

/** Eventos que falam no máximo 1x por sessão. */
export const ONE_SHOT_EVENTS: ReadonlySet<CueEvent> = new Set(['start', 'goal_reached', 'finish']);

/** Eventos resolvidos por template determinístico no fallback HTTP (sem LLM). */
export const TEMPLATE_EVENTS: ReadonlySet<CueEvent> = new Set([
  'bpm_alert',
  'pace_alert',
  'no_movement',
]);

export const TelemetrySnapshotSchema = z.object({
  kmDone: z.number().nonnegative().default(0),
  kmRemaining: z.number().nonnegative().nullish(),
  elapsedS: z.number().nonnegative().default(0),
  currentPace: z.string().nullish(),
  /** Pace dos últimos 500m ("5:30"). Usado no half_km. */
  pace500m: z.string().nullish(),
  targetPace: z.string().nullish(),
  bpm: z.number().nullish(),
  maxBpm: z.number().nullish(),
  /** Duração (s) do km recém-fechado — km_reached. */
  kmDurationS: z.number().nullish(),
  /** FC média do km recém-fechado — km_reached. */
  kmAvgBpm: z.number().nullish(),
  /** Desvio % do pace alvo — pace_alert. */
  deviationPct: z.number().nullish(),
  /** Índice 0-based do segment ativo do roteiro. */
  activeSegmentIndex: z.number().int().nonnegative().nullish(),
  /** Atleta parado (~1min sem passos no Watch). O turn ganha bandeira de
   *  estado pro LLM não alucinar pace de drift GPS (lição TF 75). */
  idle: z.boolean().nullish(),
  /** Corrida em esteira (indoor): sem GPS, distância/pace indisponíveis
   *  durante a corrida. LLM deve focar em tempo + FC. */
  indoor: z.boolean().nullish(),
});

export type TelemetrySnapshot = z.infer<typeof TelemetrySnapshotSchema>;

export interface Cue {
  event: CueEvent;
  data: TelemetrySnapshot;
  priority: CuePriority;
  enqueuedAt: number;
}
