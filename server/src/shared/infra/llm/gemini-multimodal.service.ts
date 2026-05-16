import { logger } from '@shared/logger/logger';

const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models';
const DEFAULT_MODEL = 'gemini-2.5-flash';

interface GeminiMultimodalContentPart {
  text?: string;
  inlineData?: {
    mimeType: string;
    data: string;
  };
}

interface GeminiMultimodalContent {
  role?: 'user' | 'model';
  parts: GeminiMultimodalContentPart[];
}

interface GeminiGenerateContentRequest {
  contents: GeminiMultimodalContent[];
  generationConfig?: {
    temperature?: number;
    maxOutputTokens?: number;
  };
}

interface GeminiGenerateContentResponse {
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
}

export class GeminiMultimodalService {
  private apiKey: string;
  private defaultModel: string;

  constructor(defaultModel = DEFAULT_MODEL) {
    this.apiKey = (process.env.GEMINI_API_KEY ?? '').trim();
    this.defaultModel = defaultModel;
  }

  async generateTextWithImage(
    prompt: string,
    imageData: Buffer,
    mimeType: string,
  ): Promise<string> {
    this.ensureApiKey();
    const base64Data = imageData.toString('base64');

    const request: GeminiGenerateContentRequest = {
      contents: [
        {
          parts: [
            { text: prompt },
            {
              inlineData: {
                mimeType,
                data: base64Data,
              },
            },
          ],
        },
      ],
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 2048,
      },
    };

    const start = Date.now();
    const res = await fetch(
      `${GEMINI_API_URL}/${this.defaultModel}:generateContent`,
      {
        method: 'POST',
        headers: {
          'x-goog-api-key': this.apiKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(request),
      },
    );

    if (!res.ok) {
      throw new Error(
        `Gemini multimodal error: ${res.status} ${await res.text()}`,
      );
    }

    const data = (await res.json()) as GeminiGenerateContentResponse;
    const text = this.extractText(data);
    logger.info('llm.gemini.multimodal.generate', {
      latencyMs: Date.now() - start,
      model: this.defaultModel,
      tokens: data.usageMetadata?.totalTokenCount,
    });
    return text;
  }

  async analyzeExamDocument(
    prompt: string,
    documentBuffer: Buffer,
    mimeType: string,
  ): Promise<string> {
    return this.generateTextWithImage(prompt, documentBuffer, mimeType);
  }

  private extractText(data: GeminiGenerateContentResponse): string {
    return (
      data.candidates?.[0]?.content?.parts
        ?.map(part => part.text ?? '')
        .join('') ?? ''
    );
  }

  private ensureApiKey(): void {
    if (this.apiKey) return;
    throw new Error(
      'GEMINI_API_KEY is missing. Configure it in server/.env.',
    );
  }
}
