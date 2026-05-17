export type PlanStatus = 'generating' | 'ready' | 'failed';

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
  trigger: 'weekly_cron' | 'manual' | 'event_adapt';
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
  weeks: PlanWeek[];
  mesocycleNarrative?: string; // texto LLM do mesociclo (3-4 frases)
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
  createdAt: string;
  updatedAt: string;
}
