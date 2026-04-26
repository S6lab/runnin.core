import { logger } from '@shared/logger/logger';
import { LLMOptions, LLMProvider } from './llm.interface';

const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models';
const DEFAULT_MODEL = 'gemini-2.5-flash';

type GeminiGenerateResponse = {
  candidates?: Array<{
    content?: {
      parts?: Array<{
        text?: string;
      }>;
    };
  }>;
  usageMetadata?: {
    totalTokenCount?: number;
  };
};

export class GeminiAdapter implements LLMProvider {
  private apiKey: string;
  private defaultModel: string;

  constructor(defaultModel = DEFAULT_MODEL) {
    this.apiKey = (process.env.GEMINI_API_KEY ?? '').trim();
    this.defaultModel = defaultModel;
  }

  async generate(prompt: string, options: LLMOptions = {}): Promise<string> {
    this.ensureApiKey();
    const start = Date.now();
    const model = options.model ?? this.defaultModel;
    const res = await fetch(`${GEMINI_API_URL}/${model}:generateContent`, {
      method: 'POST',
      headers: {
        'x-goog-api-key': this.apiKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(this.buildBody(prompt, options)),
    });

    if (!res.ok) throw new Error(`Gemini error: ${res.status} ${await res.text()}`);

    const data = (await res.json()) as GeminiGenerateResponse;
    const text = this.extractText(data);
    logger.info('llm.gemini.generate', {
      latencyMs: Date.now() - start,
      model,
      tokens: data.usageMetadata?.totalTokenCount,
    });
    return text;
  }

  async *stream(prompt: string, options: LLMOptions = {}): AsyncGenerator<string> {
    this.ensureApiKey();
    const start = Date.now();
    const model = options.model ?? this.defaultModel;
    const res = await fetch(`${GEMINI_API_URL}/${model}:streamGenerateContent?alt=sse`, {
      method: 'POST',
      headers: {
        'x-goog-api-key': this.apiKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(this.buildBody(prompt, options)),
    });

    if (!res.ok || !res.body) throw new Error(`Gemini stream error: ${res.status} ${await res.text()}`);

    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';
    let totalChars = 0;

    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const events = buffer.split('\n\n');
        buffer = events.pop() ?? '';

        for (const event of events) {
          for (const line of event.split('\n')) {
            if (!line.startsWith('data: ')) continue;
            const payload = line.slice(6).trim();
            if (!payload || payload === '[DONE]') continue;

            const data = JSON.parse(payload) as GeminiGenerateResponse;
            const text = this.extractText(data);
            if (!text) continue;

            totalChars += text.length;
            yield text;
          }
        }
      }
    } finally {
      reader.releaseLock();
      logger.info('llm.gemini.stream', {
        latencyMs: Date.now() - start,
        model,
        chars: totalChars,
      });
    }
  }

  private buildBody(prompt: string, options: LLMOptions): Record<string, unknown> {
    return {
      ...(options.systemPrompt
        ? {
            systemInstruction: {
              parts: [{ text: options.systemPrompt }],
            },
          }
        : {}),
      contents: [
        {
          role: 'user',
          parts: [{ text: prompt }],
        },
      ],
      generationConfig: {
        maxOutputTokens: options.maxTokens ?? 1024,
        temperature: options.temperature ?? 0.7,
      },
    };
  }

  private extractText(data: GeminiGenerateResponse): string {
    return (
      data.candidates?.[0]?.content?.parts
        ?.map(part => part.text ?? '')
        .join('') ?? ''
    );
  }

  private ensureApiKey(): void {
    if (this.apiKey) return;
    throw new Error(
      'GEMINI_API_KEY is missing. Configure it in server/.env or set LLM_ASYNC_PROVIDER to another provider.',
    );
  }
}
