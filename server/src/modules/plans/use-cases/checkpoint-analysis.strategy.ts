import { Plan, PlanWeek } from '../domain/plan.entity';
import { CheckpointInput } from '../domain/plan-checkpoint.entity';
import { BiometricSummary } from '@modules/biometrics/use-cases/get-summary.use-case';

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
  /** Snapshot biométrico dos 7d que terminaram na semana do checkpoint
   *  (HealthKit / Health Connect via biometric_samples). Cobre sono médio,
   *  recovery score, BPM repouso, HRV, peso, passos. Null quando o user
   *  não conectou wearable ou a sync falhou. Usado pra contextualizar
   *  ajustes do plano (overload sem sintomas + HRV baixo ≠ atleta forte). */
  biometricSummary?: BiometricSummary | null;
}

export interface CheckpointWeekRun {
  date: string;
  distanceKm: number;
  durationS: number;
  avgPace?: string;
  avgBpm?: number;
  maxBpm?: number;
  notes?: string;
  /** Quando != null, a run foi feita "no plano" (vinculada à sessão N).
   *  Quando null, é uma Free Run (compensação espontânea ou treino livre). */
  planSessionId?: string | null;
  /** Feedback subjetivo que o user submeteu na ReportPage da corrida.
   *  Permite ao LLM correlacionar chips ("pain", "great_week") com a run
   *  específica em vez de tratar como soup agregada. */
  userFeedback?: CheckpointInput[];
}

export interface CheckpointWeekMetrics {
  plannedSessions: number;
  completedRuns: number;
  plannedDistanceKm: number;
  actualDistanceKm: number;
  /** Volume realizado em sessões do plano (planSessionId != null). Usado
   *  pelo coach pra distinguir "fez o plano" de "compensou com free runs". */
  plannedRunsDistanceKm: number;
  /** Volume realizado em free runs (planSessionId == null). Compensa
   *  déficit de sessões planejadas — o coach precisa enxergar essa
   *  separação pra creditar o user que correu livre depois. */
  freeRunsDistanceKm: number;
  completionRate: number;        // 0..1
  avgBpm?: number;
  avgPaceMinPerKm?: number;
  /** Pace médio só das runs vinculadas a sessões do plano. */
  plannedRunsAvgPaceMinPerKm?: number;
  /** Pace médio só das free runs (compensação). */
  freeRunsAvgPaceMinPerKm?: number;
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
