export interface LLMOptions {
  maxTokens?: number;
  temperature?: number;
  systemPrompt?: string;
  model?: string;
  /**
   * Força saída em JSON válido (Gemini suporta via responseMimeType).
   * Quando true, o modelo é instruído a NUNCA quebrar JSON — elimina
   * 90%+ das falhas de parse. Usar quando o consumidor precisa parsear.
   */
  responseJson?: boolean;
  /** uid do user que disparou o call. Null = cron/system. Usado pelo
   *  usage-tracker pra atribuir custo. Best-effort: omitir não falha. */
  userId?: string | null;
  /** Tag estável do use case: 'generate-plan', 'live-coach', 'weekly-report',
   *  'analyze-exam', 'coach-message', 'narratives', 'plan-revision'.
   *  Usado pelo usage-tracker pra breakdown por feature. */
  useCase?: string;
}

export interface LLMProvider {
  generate(prompt: string, options?: LLMOptions): Promise<string>;
  stream(prompt: string, options?: LLMOptions): AsyncGenerator<string>;
}

export type LLMProviderName = 'gemini' | 'groq' | 'together';
