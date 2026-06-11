import { z } from 'zod';

/**
 * Schemas do SHAPE CRU que o LLM devolve na geração/revisão de plano.
 * É o contrato LLM→s6-ai (não o domínio do app): sem ids, sem detailLevel,
 * sem hidratação determinística — isso é responsabilidade do caller
 * (runnin-api) depois de receber as weeks válidas.
 */

export const RawPlanSegmentSchema = z.object({
  kmStart: z.number().nonnegative(),
  kmEnd: z.number().positive(),
  phase: z.string().min(1),
  targetPace: z.string().min(1).optional(),
  durationMin: z.number().positive().max(120).optional(),
  instruction: z.string().min(1).max(500),
});

export const RawPlanSessionSchema = z.object({
  dayOfWeek: z.number().int().min(1).max(7),
  type: z.string().min(1),
  distanceKm: z.number().positive().max(60),
  targetPace: z.string().min(1).optional(),
  durationMin: z.number().positive().max(600).optional(),
  hydrationLiters: z.number().positive().max(10).optional(),
  nutritionPre: z.string().max(400).optional(),
  nutritionPost: z.string().max(400).optional(),
  executionSegments: z.array(RawPlanSegmentSchema).max(20).optional(),
  notes: z.string().default(''),
});

export const RawPlanRestDayTipSchema = z.object({
  dayOfWeek: z.number().int().min(1).max(7),
  hydrationLiters: z.number().positive().max(10).optional(),
  nutrition: z.string().max(400).optional(),
  focus: z.string().max(120).optional(),
});

export const RawPlanWeekSchema = z.object({
  weekNumber: z.number().int().min(1),
  sessions: z.array(RawPlanSessionSchema).max(7),
  restDayTips: z.array(RawPlanRestDayTipSchema).max(7).optional(),
});

export const RawPlanWeeksSchema = z.array(RawPlanWeekSchema);

export type RawPlanWeek = z.infer<typeof RawPlanWeekSchema>;
export type RawPlanSession = z.infer<typeof RawPlanSessionSchema>;

/** Resposta da revisão: explicação curta + semanas futuras substituídas. */
export const RevisionSessionSchema = z.object({
  dayOfWeek: z.number().int().min(1).max(7),
  type: z.string().min(1),
  distanceKm: z.number().positive(),
  targetPace: z.string().min(1).optional(),
  notes: z.string(),
});

export const RevisionWeekSchema = z.object({
  weekNumber: z.number().int().positive(),
  sessions: z.array(RevisionSessionSchema),
  focus: z.string().optional(),
  narrative: z.string().optional(),
});

export const RevisionResponseSchema = z.object({
  coachExplanation: z.string().min(20).max(400),
  newWeeks: z.array(RevisionWeekSchema).min(1),
});

export type RevisionResponse = z.infer<typeof RevisionResponseSchema>;
