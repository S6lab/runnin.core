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
}

export interface LLMProvider {
  generate(prompt: string, options?: LLMOptions): Promise<string>;
  stream(prompt: string, options?: LLMOptions): AsyncGenerator<string>;
}

export type LLMProviderName = 'gemini' | 'groq' | 'together';
