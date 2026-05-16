/**
 * Contract central de features controladas por plano de assinatura.
 *
 * Cada chave é uma capability granular. Pra adicionar nova feature:
 * 1. Adiciona o campo aqui
 * 2. Adiciona em FREEMIUM_FEATURES + PRO_FEATURES (defaults.ts)
 * 3. Usa `requireFeature('xxx')` no router que protege a rota
 */
export interface PlanFeatures {
  // RUN
  runTracking: boolean;          // gravar corrida (GPS + duração) — base
  freeRun: boolean;              // rodar Free Run (sem plano)
  plannedRun: boolean;           // rodar a sessão prescrita do plano

  // PLAN
  generatePlan: boolean;         // gerar plano AI
  weeklyReports: boolean;        // gerar/visualizar relatório semanal
  planRevisions: boolean;        // solicitar revisão do plano

  // COACH
  coachChat: boolean;            // chat texto com Coach AI
  coachLive: boolean;            // Gemini Live (voz multimodal)
  coachVoiceDuringRun: boolean;  // voz durante corrida ativa

  // HEALTH
  healthZones: boolean;          // zonas cardíacas calculadas
  examsOCR: boolean;             // upload + OCR Gemini multimodal
  wearableSync: boolean;         // sync com Garmin/Polar/etc (futuro OAuth)

  // SHARE / HIST
  shareWithOverlay: boolean;     // share card foto+overlay
  historyExport: boolean;        // exportar histórico CSV/JSON
}

/**
 * Limites quantitativos por plano (rate limits + cotas).
 */
export interface PlanLimits {
  plansPerMonth: number;         // qtd de planos AI que pode gerar/mês
  examsPerMonth: number;         // uploads de exame/mês
  coachMessagesPerDay: number;   // mensagens no chat coach/dia
  weeklyReportsPerMonth: number; // relatórios semanais gerados/mês
}
