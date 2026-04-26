import { LLMOptions, LLMProvider } from './llm.interface';
import { logger } from '@shared/logger/logger';

const TOGETHER_API_URL = 'https://api.together.xyz/v1/chat/completions';
const DEFAULT_MODEL = 'deepseek-ai/DeepSeek-V3';

export class TogetherAdapter implements LLMProvider {
  private apiKey: string;

  constructor() {
    this.apiKey = process.env.TOGETHER_API_KEY ?? '';
  }

  async generate(prompt: string, options: LLMOptions = {}): Promise<string> {
    const start = Date.now();
    const res = await fetch(TOGETHER_API_URL, {
      method: 'POST',
      headers: { Authorization: `Bearer ${this.apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: DEFAULT_MODEL,
        max_tokens: options.maxTokens ?? 1024,
        temperature: options.temperature ?? 0.7,
        messages: [
          ...(options.systemPrompt ? [{ role: 'system', content: options.systemPrompt }] : []),
          { role: 'user', content: prompt },
        ],
      }),
    });

    if (!res.ok) throw new Error(`Together error: ${res.status} ${await res.text()}`);
    const data = await res.json() as { choices: { message: { content: string } }[]; usage: { total_tokens: number } };
    logger.info('llm.together.generate', { latencyMs: Date.now() - start, tokens: data.usage.total_tokens });
    return data.choices[0].message.content;
  }

  async *stream(_prompt: string, _options: LLMOptions = {}): AsyncGenerator<string> {
    // Together usado para geração assíncrona (plano, relatório) — não precisa de stream
    throw new Error('Use generate() for Together AI');
    yield '';
  }
}
