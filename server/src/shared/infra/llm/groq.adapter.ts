import { LLMOptions, LLMProvider } from './llm.interface';
import { logger } from '@shared/logger/logger';

const GROQ_API_URL = 'https://api.groq.com/openai/v1/chat/completions';
const DEFAULT_MODEL = 'qwen/qwen3-32b';

export class GroqAdapter implements LLMProvider {
  private apiKey: string;

  constructor() {
    this.apiKey = process.env.GROQ_API_KEY ?? '';
  }

  async generate(prompt: string, options: LLMOptions = {}): Promise<string> {
    const start = Date.now();
    const res = await fetch(GROQ_API_URL, {
      method: 'POST',
      headers: { Authorization: `Bearer ${this.apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: DEFAULT_MODEL,
        max_tokens: options.maxTokens ?? 256,
        temperature: options.temperature ?? 0.7,
        messages: [
          ...(options.systemPrompt ? [{ role: 'system', content: options.systemPrompt }] : []),
          { role: 'user', content: prompt },
        ],
      }),
    });

    if (!res.ok) throw new Error(`Groq error: ${res.status} ${await res.text()}`);
    const data = await res.json() as { choices: { message: { content: string } }[]; usage: { total_tokens: number } };
    logger.info('llm.groq.generate', { latencyMs: Date.now() - start, tokens: data.usage.total_tokens });
    return data.choices[0].message.content;
  }

  async *stream(prompt: string, options: LLMOptions = {}): AsyncGenerator<string> {
    const start = Date.now();
    const res = await fetch(GROQ_API_URL, {
      method: 'POST',
      headers: { Authorization: `Bearer ${this.apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: DEFAULT_MODEL,
        max_tokens: options.maxTokens ?? 128,
        temperature: options.temperature ?? 0.7,
        stream: true,
        messages: [
          ...(options.systemPrompt ? [{ role: 'system', content: options.systemPrompt }] : []),
          { role: 'user', content: prompt },
        ],
      }),
    });

    if (!res.ok || !res.body) throw new Error(`Groq stream error: ${res.status}`);

    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let totalTokens = 0;

    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        const lines = decoder.decode(value).split('\n').filter(l => l.startsWith('data: '));
        for (const line of lines) {
          const raw = line.slice(6);
          if (raw === '[DONE]') continue;
          const chunk = JSON.parse(raw) as { choices: { delta: { content?: string } }[] };
          const content = chunk.choices[0]?.delta?.content;
          if (content) { totalTokens++; yield content; }
        }
      }
    } finally {
      reader.releaseLock();
      logger.info('llm.groq.stream', { latencyMs: Date.now() - start, tokens: totalTokens });
    }
  }
}
