export interface LLMOptions {
  maxTokens?: number;
  temperature?: number;
  systemPrompt?: string;
  model?: string;
}

export interface LLMProvider {
  generate(prompt: string, options?: LLMOptions): Promise<string>;
  stream(prompt: string, options?: LLMOptions): AsyncGenerator<string>;
}

export type LLMProviderName = 'gemini' | 'groq' | 'together';
