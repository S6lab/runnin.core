import { logger } from '@shared/logger/logger';
import { LLMOptions, LLMProvider } from './llm.interface';
import { trackLlmUsage } from './usage-tracker';

const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models';
// Modelo de texto. Override via env GEMINI_MODEL (ex: gemini-flash-latest,
// gemini-3.1-pro-preview) pra A/B sem redeploy de código.
const DEFAULT_MODEL = process.env['GEMINI_MODEL']?.trim() || 'gemini-3.5-flash';

type GeminiGenerateResponse = {
  candidates?: Array<{
    content?: {
      parts?: Array<{
        text?: string;
      }>;
    };
    /** STOP=ok, MAX_TOKENS=hit limit, SAFETY=blocked by safety filter,
     *  RECITATION=blocked, OTHER=internal */
    finishReason?: string;
    safetyRatings?: Array<{ category?: string; probability?: string; blocked?: boolean }>;
  }>;
  promptFeedback?: {
    blockReason?: string;
    safetyRatings?: Array<{ category?: string; probability?: string; blocked?: boolean }>;
  };
  usageMetadata?: {
    totalTokenCount?: number;
    promptTokenCount?: number;
    candidatesTokenCount?: number;
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
    const finishReason = data.candidates?.[0]?.finishReason;
    // Loga finishReason sempre — antes não capturávamos, então um SAFETY
    // ou MAX_TOKENS silenciava e salvávamos texto truncado sem aviso.
    const meta: Record<string, unknown> = {
      latencyMs: Date.now() - start,
      model,
      tokens: data.usageMetadata?.totalTokenCount,
      promptTokens: data.usageMetadata?.promptTokenCount,
      outputTokens: data.usageMetadata?.candidatesTokenCount,
      finishReason,
    };
    if (data.promptFeedback?.blockReason) {
      meta['promptBlockReason'] = data.promptFeedback.blockReason;
    }
    if (finishReason && finishReason !== 'STOP' && finishReason !== 'MAX_TOKENS') {
      logger.warn('llm.gemini.generate.non_stop', { ...meta, chars: text.length });
    } else {
      logger.info('llm.gemini.generate', meta);
    }
    // Persiste agregado em Firestore (best-effort, falha silenciosa). Caller
    // passa userId + useCase via LLMOptions. Sem esses, atribui a 'system'/
    // 'unknown' pra ter o gasto contabilizado mesmo sem tagging.
    void trackLlmUsage({
      userId: options.userId ?? null,
      useCase: options.useCase ?? 'unknown',
      model,
      promptTokens: data.usageMetadata?.promptTokenCount ?? 0,
      outputTokens: data.usageMetadata?.candidatesTokenCount ?? 0,
      latencyMs: Date.now() - start,
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
      // Safety filters relaxados pra BLOCK_NONE: o runnin é app de coach de
      // CORRIDA, conteúdo médico (condições, medicações, lesões) é parte
      // central do contexto que o LLM precisa raciocinar. Default BLOCK_MEDIUM
      // estava truncando rationale silenciosamente em planos com perfil
      // médico (diverticulite, betabloqueador, tendão rompido etc).
      safetySettings: [
        { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_NONE' },
        { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_NONE' },
        { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_NONE' },
        { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_NONE' },
      ],
      generationConfig: {
        maxOutputTokens: options.maxTokens ?? 1024,
        temperature: options.temperature ?? 0.7,
        // responseMimeType:'application/json' força saída JSON válida —
        // Gemini garante schema bem-formado, elimina quebras de aspas
        // e vírgulas trailing. Crítico pra plan generation.
        ...(options.responseJson ? { responseMimeType: 'application/json' } : {}),
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
