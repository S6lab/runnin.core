import WebSocket, { RawData } from 'ws';
import { logger } from '@shared/logger/logger';

const GEMINI_LIVE_URL = 'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent';
const DEFAULT_MODEL = 'models/gemini-2.0-flash-exp';

export interface GeminiLiveConfig {
  model?: string;
  systemInstruction?: string;
  /** voice = 'Puck' | 'Charon' | 'Kore' | 'Fenrir' | 'Aoede' (default voices Gemini Live) */
  voice?: string;
  /** "AUDIO" | "TEXT" — TEXT mode útil pra debug sem áudio */
  responseModalities?: Array<'AUDIO' | 'TEXT'>;
}

/**
 * Cliente WebSocket pro Gemini Live API (audio-to-audio bidirecional).
 *
 * Uso típico: chamado pelo CoachLiveSessionController que faz proxy entre
 * Flutter (browser WebSocket) e Gemini Live (server-side WebSocket).
 * Mantém API key segura no servidor.
 *
 * Fluxo:
 *  1. open() — abre WS, envia setup, aguarda SetupComplete
 *  2. sendAudio() / sendText() — envia chunks do user
 *  3. onMessage callback recebe deltas do modelo (audio ou text)
 *  4. close() — encerra
 */
export class GeminiLiveSession {
  private ws: WebSocket | null = null;
  private apiKey: string;
  private config: Required<Pick<GeminiLiveConfig, 'model' | 'responseModalities'>> & GeminiLiveConfig;
  private onMessage: (msg: GeminiLiveMessage) => void;
  private onClose: ((code: number, reason: string) => void) | undefined;
  private setupComplete = false;

  constructor(args: {
    config: GeminiLiveConfig;
    onMessage: (msg: GeminiLiveMessage) => void;
    onClose?: (code: number, reason: string) => void;
  }) {
    this.apiKey = (process.env.GEMINI_API_KEY ?? '').trim();
    this.config = {
      model: args.config.model ?? DEFAULT_MODEL,
      responseModalities: args.config.responseModalities ?? ['AUDIO'],
      systemInstruction: args.config.systemInstruction,
      voice: args.config.voice,
    };
    this.onMessage = args.onMessage;
    this.onClose = args.onClose;
  }

  open(): Promise<void> {
    if (!this.apiKey) throw new Error('GEMINI_API_KEY not configured');

    return new Promise((resolve, reject) => {
      const url = `${GEMINI_LIVE_URL}?key=${this.apiKey}`;
      this.ws = new WebSocket(url);

      this.ws.on('open', () => {
        const setupMsg: Record<string, unknown> = {
          setup: {
            model: this.config.model,
            generationConfig: {
              responseModalities: this.config.responseModalities,
              ...(this.config.voice && this.config.responseModalities?.includes('AUDIO')
                ? {
                    speechConfig: {
                      voiceConfig: { prebuiltVoiceConfig: { voiceName: this.config.voice } },
                    },
                  }
                : {}),
            },
            ...(this.config.systemInstruction
              ? { systemInstruction: { parts: [{ text: this.config.systemInstruction }] } }
              : {}),
          },
        };
        this.ws!.send(JSON.stringify(setupMsg));
      });

      this.ws.on('message', (data: RawData) => {
        try {
          const text = data.toString('utf-8');
          const parsed = JSON.parse(text) as GeminiLiveServerEnvelope;
          if (!this.setupComplete && parsed.setupComplete) {
            this.setupComplete = true;
            resolve();
            return;
          }
          if (parsed.serverContent) {
            this.onMessage({ kind: 'content', serverContent: parsed.serverContent });
          } else if (parsed.toolCall) {
            this.onMessage({ kind: 'toolCall', toolCall: parsed.toolCall });
          }
        } catch (err) {
          logger.warn('gemini.live.message_parse_failed', { err: String(err) });
        }
      });

      this.ws.on('error', (err) => {
        logger.error('gemini.live.ws_error', { err: String(err) });
        if (!this.setupComplete) reject(err);
      });

      this.ws.on('close', (code, reason) => {
        this.onClose?.(code, reason.toString('utf-8'));
      });
    });
  }

  /** Envia chunk PCM 16kHz 16-bit mono. data = base64. */
  sendAudio(data: string, mimeType = 'audio/pcm;rate=16000'): void {
    this.sendRealtime({ mimeType, data });
  }

  sendText(text: string): void {
    this.ws?.send(JSON.stringify({
      clientContent: {
        turns: [{ role: 'user', parts: [{ text }] }],
        turnComplete: true,
      },
    }));
  }

  private sendRealtime(media: { mimeType: string; data: string }): void {
    this.ws?.send(JSON.stringify({ realtimeInput: { mediaChunks: [media] } }));
  }

  close(): void {
    this.ws?.close();
    this.ws = null;
  }
}

// ───────────────────────────── Tipos ─────────────────────────────

interface GeminiLiveServerEnvelope {
  setupComplete?: Record<string, unknown>;
  serverContent?: GeminiServerContent;
  toolCall?: GeminiToolCall;
}

export interface GeminiServerContent {
  modelTurn?: {
    parts: Array<{
      text?: string;
      inlineData?: { mimeType: string; data: string };
    }>;
  };
  turnComplete?: boolean;
  interrupted?: boolean;
}

export interface GeminiToolCall {
  functionCalls?: Array<{ name: string; args: Record<string, unknown>; id?: string }>;
}

export type GeminiLiveMessage =
  | { kind: 'content'; serverContent: GeminiServerContent }
  | { kind: 'toolCall'; toolCall: GeminiToolCall };
