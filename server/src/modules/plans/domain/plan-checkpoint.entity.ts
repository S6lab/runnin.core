/**
 * PlanCheckpoint — ponto de revisão semanal do plano.
 *
 * Regra de negócio: o plano só pode ser ajustado 1x por semana. Cada
 * semana do mesociclo tem 1 checkpoint agendado pra D+6 (último dia
 * da semana, conforme periodização). O usuário pode entrar nele a
 * qualquer momento; ao apresentar inputs e pedir aplicação, dispara
 * a estratégia de análise (LLM por default) que produz uma PlanRevision
 * aplicada às semanas seguintes.
 *
 * Estado:
 *   scheduled    — criado no ready do plano, ainda sem atividade
 *   in_progress  — user abriu e/ou submeteu inputs, ainda não aplicou
 *   completed    — apply rodou e gerou revision (link em resultRevisionId)
 *   skipped      — passou da data sem apply (cron de housekeeping marca)
 */
export type PlanCheckpointStatus =
  | 'scheduled'
  | 'in_progress'
  | 'completed'
  | 'skipped';

/**
 * Inputs pré-determinados que o user marca via chips no app. `note`
 * opcional acompanha pra detalhar (ex: pain → "joelho direito desde
 * sábado").
 */
export type CheckpointInputType =
  | 'load_up'           // "aumenta a carga"
  | 'load_down'         // "diminui a carga"
  | 'pain'              // "dor específica"
  | 'schedule_conflict' // "agenda apertada essa semana"
  | 'low_energy'        // "sem energia / cansaço"
  | 'sleep_bad'         // "dormindo mal"
  | 'great_week'        // "semana foi boa, vamos subir"
  | 'other';            // free text obrigatório

export interface CheckpointInput {
  type: CheckpointInputType;
  /** Texto curto (até 280 chars) detalhando o input. Obrigatório
   *  quando `type === 'other'` ou `pain`. */
  note?: string;
}

export interface PlanCheckpoint {
  id: string;            // `${planId}_${weekNumber}`
  planId: string;
  userId: string;
  weekNumber: number;    // 1..weeksCount
  /** ISO YYYY-MM-DD — dia em que o checkpoint "vence" (último dia da
   *  semana N). User pode abrir antes; cron marca skipped depois. */
  scheduledDate: string;
  status: PlanCheckpointStatus;
  /** Inputs submetidos pelo user. Pode ter 0..N entries; apply usa
   *  todos. */
  userInputs?: CheckpointInput[];
  /** Texto curto (1-3 frases) do que a IA leu da semana (aderência,
   *  km feitos, BPM médio, pace médio). Pode ser populado já no GET
   *  de detalhe pra o user ver antes de apertar APLICAR. */
  autoAnalysis?: string;
  /** Id da PlanRevision criada no apply. Permite navegar pro snapshot
   *  e ver o que mudou. */
  resultRevisionId?: string;
  openedAt?: string;     // primeira vez que user abriu
  completedAt?: string;  // quando apply rodou
  createdAt: string;
}
