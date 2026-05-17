import { Plan, PlanWeek } from '../domain/plan.entity';
import { CheckpointInput } from '../domain/plan-checkpoint.entity';

/**
 * Insumos pra estratégia de análise de checkpoint:
 *   - plano atual completo
 *   - número da semana sendo analisada (a que ACABA aqui)
 *   - inputs do user (chips + frees) submetidos
 *   - dados objetivos da semana: corridas concluídas, métricas
 *
 * Estratégia devolve:
 *   - texto curto (autoAnalysis) — o que ela leu
 *   - newWeeks (snapshot ajustado das semanas SEGUINTES, weekNumber+1..N)
 *   - coachExplanation longa — racional do ajuste (markdown)
 *
 * Manter como interface permite plugar variações: LLM (default),
 * heurística rule-based, A/B test.
 */
export interface CheckpointAnalysisInput {
  plan: Plan;
  weekNumber: number;
  userInputs: CheckpointInput[];
  weekRuns: CheckpointWeekRun[];
  weekMetrics: CheckpointWeekMetrics;
}

export interface CheckpointWeekRun {
  date: string;
  distanceKm: number;
  durationS: number;
  avgPace?: string;
  avgBpm?: number;
  maxBpm?: number;
  notes?: string;
}

export interface CheckpointWeekMetrics {
  plannedSessions: number;
  completedRuns: number;
  plannedDistanceKm: number;
  actualDistanceKm: number;
  completionRate: number;        // 0..1
  avgBpm?: number;
  avgPaceMinPerKm?: number;
}

export interface CheckpointAnalysisOutput {
  autoAnalysis: string;
  /** Snapshot ajustado das semanas seguintes (weekNumber+1..N).
   *  Devolva [] se não houve ajuste. */
  newWeeks: PlanWeek[];
  /** Markdown longo explicando o que mudou e por quê. */
  coachExplanation: string;
}

export interface CheckpointAnalysisStrategy {
  analyze(input: CheckpointAnalysisInput): Promise<CheckpointAnalysisOutput>;
}
