/**
 * Tabela de preço LLM em USD por 1M tokens. Hardcoded — atualizar manualmente
 * quando Google/Together/Groq mudarem pricing. Valores aproximados de 06/2026.
 *
 * Override via Firestore `app_config/llm_pricing` (admin pode editar sem deploy).
 * Cache 60s — fallback nesta tabela se Firestore down.
 *
 * Refs:
 *   - https://ai.google.dev/pricing (Google AI)
 *   - https://www.together.ai/pricing
 *   - https://groq.com/pricing
 */
export interface ModelPricing {
  /** USD per 1M input tokens. */
  inputPer1M: number;
  /** USD per 1M output tokens. */
  outputPer1M: number;
}

export const LLM_PRICING_USD_PER_1M: Record<string, ModelPricing> = {
  // Google AI (Gemini)
  'gemini-3.5-flash':              { inputPer1M: 0.075, outputPer1M: 0.30 },
  'gemini-3.1-pro-preview':        { inputPer1M: 1.25,  outputPer1M: 5.00 },
  'gemini-2.5-flash-native-audio': { inputPer1M: 0.15,  outputPer1M: 1.00 },
  'gemini-embedding-001':          { inputPer1M: 0.025, outputPer1M: 0 },
  // Together
  'meta-llama/Llama-3.3-70B-Instruct-Turbo':    { inputPer1M: 0.88, outputPer1M: 0.88 },
  // Groq
  'llama-3.3-70b-versatile':       { inputPer1M: 0.59, outputPer1M: 0.79 },
};

/**
 * Calcula custo em USD pra uma chamada LLM. Retorna 0 se modelo desconhecido
 * (não dá pra zerar a métrica — log de warn no caller pra capturar gap).
 */
export function computeCostUsd(
  model: string,
  promptTokens: number,
  outputTokens: number,
): number {
  const pricing = LLM_PRICING_USD_PER_1M[model];
  if (!pricing) return 0;
  const inputCost = (promptTokens / 1_000_000) * pricing.inputPer1M;
  const outputCost = (outputTokens / 1_000_000) * pricing.outputPer1M;
  return inputCost + outputCost;
}

/** Lista de modelos cobertos pela tabela. Admin UI usa pra mostrar gaps. */
export function listKnownModels(): string[] {
  return Object.keys(LLM_PRICING_USD_PER_1M);
}
