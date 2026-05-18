/**
 * Status do relatório two-phase:
 * - pending      → nada gerado ainda (LLM rodando ou erro pendente)
 * - summary_ready→ texto curto gerado (~30s pós-finish), basta pro user
 *                  ler na ReportPage enquanto a fase enriched roda
 * - enriched     → sections (análise, evolução, próximas, recomendações)
 *                  prontas, plano adaptado já refletido
 * - ready        → legacy: reports antigos (single-phase) ficaram com esse
 *                  status. UI trata como summary_ready pra retrocompat.
 */
export type CoachReportStatus = 'pending' | 'summary_ready' | 'enriched' | 'ready';

/** Bloco de 4 seções produzidas pela fase enriched. Cada uma é texto
 *  corrido (1-2 parágrafos) — UI renderiza como ExpansionTile. */
export interface CoachReportSections {
  /** Análise da corrida que acabou (pace, esforço, execução vs plano). */
  runAnalysis: string;
  /** Evolução no plano: tendência das últimas semanas, consistência. */
  planEvolution: string;
  /** Próximas sessões: o que vem no plano + ajustes recomendados. */
  nextSessions: string;
  /** Recomendações práticas: nutrição, recuperação, atenção a sinais. */
  recommendations: string;
}

export interface CoachReport {
  runId: string;
  userId: string;
  summary: string;
  status: CoachReportStatus;
  generatedAt: string;
  /** Resultado da fase enriched. Null em reports legados ou enquanto
   *  a fase B ainda não rodou (status=summary_ready). */
  sections?: CoachReportSections;
  /** Timestamp de quando a fase enriched terminou. */
  enrichedAt?: string;
}
