import { PromptSource } from '../versions';

export interface BuiltPrompt {
  systemPrompt: string;
  userPrompt: string;
  maxTokens: number;
  temperature: number;
  ragChunks: number;
  version: string;
  source: PromptSource;
}
