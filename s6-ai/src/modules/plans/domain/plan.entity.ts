/**
 * Estados do plano:
 *  - 'generating': LLM gerando (assíncrono); UI mostra countdown.
 *  - 'ready': plano vivo, em uso. Cron de domingo gera checkpoints.
 *  - 'failed': IA falhou; user tem que regerar.
 *  - 'completed': mesociclo terminou (mesocycleEndDate < hoje). Plano fica
 *    arquivado e abre a tela de relatório final (/training/plan-report/:id).
 *    User volta pra estado "sem plano" no TREINO e refaz a jornada se quiser
 *    outro plano. Detecção lazy no GetCurrentPlanUseCase (não tem cron).
 */
export type PlanStatus = 'generating' | 'ready' | 'failed' | 'completed';

/**
 * Segmento de execução da sessão — uma fase específica da corrida
 * (ex: km 0-1 aquecimento, km 1-4 pace alvo, km 4-5 cooldown).
 * Renderizado no DayDetailPage como timeline ordenada, com a
 * instrução exata do coach pra cada fase. É o "execution script".
 */
export interface PlanSegment {
  /** Início do segmento em km (cumulativo desde 0). */
  kmStart: number;
  /** Fim do segmento em km. */
  kmEnd: number;
  /** Tipo: warmup | main | interval | recovery | cooldown */
  phase: string;
  /** Pace alvo pra esse segmento. Null em warmup/cooldown. */
  targetPace?: string;
  /** Tempo estimado do segmento (min). */
  durationMin?: number;
  /** Instrução literal do coach pra o atleta executar a fase. */
  instruction: string;
}

export interface PlanSession {
  id: string;
  dayOfWeek: number; // 1=Mon … 7=Sun
  type: string;
  distanceKm: number;
  targetPace?: string;
  /** Tempo alvo da sessão em minutos (ex: 45). Derivado de distância × pace
   *  pelo coach, mas pode ser definido explicitamente (sessões por tempo). */
  durationMin?: number;
  /** Hidratação sugerida pra ESSE dia (litros totais), wired nas
   *  notificações diárias. Considera peso × 0.035L + carga do treino. */
  hydrationLiters?: number;
  /** Sugestão de refeição pré-treino (60-90min antes). */
  nutritionPre?: string;
  /** Sugestão de refeição pós-treino (até 1h depois). */
  nutritionPost?: string;
  /** Execution script: timeline km-a-km com instrução do coach por
   *  fase. Renderizado no DayDetailPage. Plano completo só mostra
   *  agregado (pace/distância/tempo). */
  executionSegments?: PlanSegment[];
  notes: string;
  /** ID da Run que executou essa sessão. Setado em CompleteRunUseCase
   *  quando run.planSessionId == session.id. Null = sessão não feita
   *  ainda. App usa pra: (1) mostrar sessão "feita" no plano, (2) avisar
   *  o user antes de re-executar (sobrescreveria a anterior). */
  executedRunId?: string;
  executedAt?: string;
  /** Marca a sessão-meta (a "prova" do plano RACE) — última sessão da
   *  última semana. Isenta do cap MAX_KM_PER_SESSION (essa sessão TEM a
   *  distância da prova, não importa o nível) e renderiza com badge no
   *  UI. Setado pelo `markTargetSession()` pós-LLM. */
  isTarget?: boolean;
}

/**
 * Tip diária pra dias SEM sessão (descanso). O coach define hidratação +
 * alimentação anti-inflamatória mesmo nos dias de folga, pra manter a
 * jornada consistente.
 */
export interface PlanRestDayTip {
  dayOfWeek: number; // 1=Mon … 7=Sun
  hydrationLiters?: number;
  nutrition?: string; // ex: "anti-inflamatório, leveza + vegetais variados"
  focus?: string; // "recuperação ativa" | "alongamento" | "fortalecimento" | etc
}

export interface PlanWeek {
  weekNumber: number;
  sessions: PlanSession[];
  focus?: string;       // "Base" | "Intervalado" | "Tempo" | "Recuperação"
  narrative?: string;   // texto LLM da semana (1-2 frases)
  /**
   * Nível de detalhe da semana (geração two-tier):
   *  - 'full': sessões completas (pace, tempo, hidratação, nutrição, notes
   *    ricas, executionSegments). Sempre as 2 primeiras semanas + as 2
   *    enriquecidas a cada checkpoint.
   *  - 'skeleton': só tipo + distância + pace alvo + metadados do bloco.
   *    Demais campos liberados no checkpoint da semana anterior.
   * Default (ausente) = 'full' para retrocompatibilidade com planos antigos.
   */
  detailLevel?: 'full' | 'skeleton';
  /** Nome didático do bloco/fase da semana (ex: "BASE · Adaptação"). */
  blockName?: string;
  /** Objetivo da semana em 1 frase (ex: "Construir base aeróbica"). */
  objective?: string;
  /** Carga projetada da semana em km (soma planejada do volume). */
  projectedLoadKm?: number;
  /** Objetivos a atingir na semana, em bullets curtos. */
  targets?: string[];
  /** Orientação para os dias SEM treino dessa semana (descanso, recuperação,
   *  alongamento). Wired nas notificações diárias quando não há sessão. */
  restDayTips?: PlanRestDayTip[];
}

/**
 * Uma revisão semanal automática do plano: o coach lê as corridas
 * concluídas, exames novos, condições reportadas e reajusta as semanas
 * seguintes. O log fica anexado ao plano original (não substitui) pra
 * o atleta ver a evolução: plano inicial → revisão sem 1 → revisão sem
 * 2 → ...
 */
export interface PlanRevision {
  weekNumber: number;             // qual semana foi revisada (1, 2, 3...)
  revisedAt: string;              // ISO timestamp
  trigger: 'weekly_cron' | 'manual' | 'event_adapt' | 'checkpoint';
  summary: string;                // texto curto do que mudou (1-2 frases)
  details?: string;               // markdown longo da análise (opcional)
  // Snapshot do que mudou em comparação à versão anterior do plano.
  // Não precisa ser exaustivo — é pra leitura humana, não pra rollback.
  changes?: {
    sessionsAdjusted?: number;
    volumeDelta?: number;          // km diff
    intensityShift?: 'increased' | 'decreased' | 'unchanged';
  };
}

export interface Plan {
  id: string;
  userId: string;
  goal: string;
  level: string;
  weeksCount: number;
  status: PlanStatus;
  /**
   * Data D0 escolhida pelo atleta no onboarding (ISO YYYY-MM-DD). O dia
   * `dayOfWeek` da PRIMEIRA semana é o weekday dessa data. Mesociclo
   * termina em startDate + (weeksCount × 7) - 1 dias.
   * Default = createdAt date.
   */
  startDate?: string;
  /**
   * BASE IMUTÁVEL — semanas geradas na criação do plano. Nunca alteradas
   * por revisões/checkpoints. Tela "VER PLANO BASE" lê DAQUI. Permite ao
   * atleta sempre comparar o que foi planejado vs. o que está vigente.
   */
  weeks: PlanWeek[];
  /**
   * SEMANAS VIGENTES (snapshot acumulado das revisões aplicadas). Quando
   * null/ausente, equivale a `weeks` (sem nenhuma revisão aplicada ainda).
   * Telas de treino / RUN 1-5 / progresso semanal / mensal leem DAQUI via
   * helper `effectivePlanWeeks(plan)`. Cada revisão semanal regrava esse
   * campo; `weeks` permanece intocada.
   */
  adjustedWeeks?: PlanWeek[];
  mesocycleNarrative?: string; // texto LLM do mesociclo (3-4 frases)
  /**
   * Avaliação honesta do objetivo declarado pelo atleta: o coach analisa o
   * gap entre o estado atual (nível/idade/peso/condições) e a meta, e diz se
   * é alcançável neste mesociclo ou se este plano é só a fundação. Campo
   * dedicado (distinto de coachRationale e mesocycleNarrative), renderizado
   * em destaque na /training/plan-detail. Gerado junto do plano.
   */
  goalAssessment?: string;
  /**
   * Texto markdown longo escrito pelo coach AI explicando o plano: dados
   * considerados, racional de carga, periodização, contraindicações,
   * recomendações nutricionais/recuperação. Renderizado na página
   * /training/plan-detail. Gerado em background após o plano ficar 'ready'.
   */
  coachRationale?: string;
  /**
   * Histórico de revisões automáticas (cron semanal) ou manuais. Cada
   * entrada documenta o que foi ajustado e por quê. O plano evolui sem
   * apagar o histórico — o atleta vê a jornada toda.
   */
  revisions?: PlanRevision[];
  /**
   * Prazo inicial (ISO YYYY-MM-DD) pra atingir o objetivo, gravado na criação
   * do plano (= startDate + weeksCount × 7d). Imutável após criado — o coach
   * pode ajustar weeksCount via checkpoint, mas o prazo INICIAL fica registrado
   * pro relatório final ("prazo inicial × prazo real").
   */
  initialDeadlineAt?: string;
  /**
   * Data da prova (ISO YYYY-MM-DD) quando goalKind=race. Ancora o último dia
   * do mesociclo — a revisão semanal NÃO pode mudar isso. Vive aqui no plano
   * (e não só no UserProfile) pra que o user possa marcar uma prova futura
   * sem afetar o plano em execução. Setada na criação a partir do input do
   * onboarding RACE.
   */
  raceDate?: string;
  /**
   * Dia da semana da prova (1=Mon..7=Sun) derivado de raceDate. Armazenado
   * separadamente porque é consultado em hot path (markTargetSession,
   * enforce-race-week) e evita ter que reparsear raceDate todo lugar.
   */
  raceDayOfWeek?: number;
  /**
   * Data em que o plano foi marcado como completed. Setado pela detecção lazy
   * no GetCurrentPlanUseCase quando mesocycleEndDate < hoje. Usado no relatório
   * final pra comparar com initialDeadlineAt.
   */
  completedAt?: string;
  createdAt: string;
  updatedAt: string;
}

/**
 * Semanas VIGENTES (com revisões aplicadas). Fallback: `weeks` base quando
 * nenhum ajuste foi registrado. Todos os consumers (treino, RUN 1-5, stats,
 * coach context) DEVEM usar este helper em vez de `plan.weeks` diretamente —
 * caso contrário a UI ignora os ajustes do cron semanal.
 */
export function effectivePlanWeeks(plan: Pick<Plan, 'weeks' | 'adjustedWeeks'>): PlanWeek[] {
  return plan.adjustedWeeks && plan.adjustedWeeks.length > 0
    ? plan.adjustedWeeks
    : plan.weeks;
}
