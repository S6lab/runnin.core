import { z } from 'zod';

/**
 * ARQUIVO EM EXTINÇÃO (migração s6-ai): a geração de cues de corrida vive
 * agora no s6-ai (CueQueue + Gemini bridge server-side). O endpoint
 * /coach/message foi removido; replay do histórico virou
 * list-coach-messages.use-case.ts.
 *
 * Só resta o tipo CoachContext, importado por template-cues.ts (também em
 * extinção — os templates ativos vivem em s6-ai/src/modules/live/).
 * Deletar os dois arquivos + specs no próximo `git rm` (vide
 * scripts/validate-s6ai-migration.sh).
 */

export const CoachContextSchema = z.object({
  runId: z.string().optional(),
  event: z.enum([
    'pre_run',
    'km_reached',
    'km_split',
    'pace_alert',
    'motivation',
    'question',
    'start',
    'finish',
    'preview',
    'check_in',
    'goal_reached',
    'high_bpm',
    'no_movement',
    'segment_start',
    'segment_pace_off',
    'segment_end',
  ]),
  runType: z.string().optional(),
  currentPaceMinKm: z.number().default(0),
  targetPaceMinKm: z.number().optional(),
  targetDistance: z.string().optional(),
  distanceM: z.number().default(0),
  elapsedS: z.number().default(0),
  bpm: z.number().optional(),
  kmReached: z.number().optional(),
  kmDurationS: z.number().optional(),
  kmAvgBpm: z.number().optional(),
  question: z.string().optional(),
  voiceId: z.string().optional(),
  planSessionId: z.string().optional(),
  currentSegmentIndex: z.number().int().nonnegative().optional(),
  temperatureC: z.number().optional(),
  humidityPercent: z.number().optional(),
  windKmh: z.number().optional(),
});

export type CoachContext = z.infer<typeof CoachContextSchema>;
