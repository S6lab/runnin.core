import { logger } from '@shared/logger/logger';

const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models';
const DEFAULT_MODEL = 'gemini-embedding-001';

type GeminiEmbeddingTaskType = 'RETRIEVAL_DOCUMENT' | 'RETRIEVAL_QUERY';

type GeminiEmbedContentResponse = {
  embedding?: {
    values?: number[];
  };
};

export class GeminiEmbeddingService {
  private apiKey: string;
  private model: string;

  constructor(model = process.env.GEMINI_EMBEDDING_MODEL ?? DEFAULT_MODEL) {
    this.apiKey = (process.env.GEMINI_API_KEY ?? '').trim();
    this.model = model.trim() || DEFAULT_MODEL;
  }

  get modelName(): string {
    return this.model;
  }

  async embedDocument(text: string, title?: string): Promise<number[]> {
    return this.embed(text, 'RETRIEVAL_DOCUMENT', title);
  }

  async embedQuery(text: string): Promise<number[]> {
    return this.embed(text, 'RETRIEVAL_QUERY');
  }

  private async embed(
    text: string,
    taskType: GeminiEmbeddingTaskType,
    title?: string,
  ): Promise<number[]> {
    this.ensureApiKey();
    const trimmed = text.replace(/\s+/g, ' ').trim();
    if (!trimmed) return [];

    const start = Date.now();
    const res = await fetch(`${GEMINI_API_URL}/${this.model}:embedContent`, {
      method: 'POST',
      headers: {
        'x-goog-api-key': this.apiKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: `models/${this.model}`,
        content: {
          parts: [{ text: trimmed }],
        },
        taskType,
        ...(taskType === 'RETRIEVAL_DOCUMENT' && title ? { title } : {}),
      }),
    });

    if (!res.ok) throw new Error(`Gemini embedding error: ${res.status} ${await res.text()}`);

    const data = (await res.json()) as GeminiEmbedContentResponse;
    const values = data.embedding?.values ?? [];
    logger.info('embedding.gemini.embed', {
      latencyMs: Date.now() - start,
      model: this.model,
      taskType,
      dimensions: values.length,
    });
    return values;
  }

  private ensureApiKey(): void {
    if (this.apiKey) return;
    throw new Error('GEMINI_API_KEY is missing. Embeddings require the Gemini API key.');
  }
}
