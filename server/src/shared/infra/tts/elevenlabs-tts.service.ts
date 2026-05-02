import { logger } from '@shared/logger/logger';

export interface ElevenLabsTtsOptions {
  voiceId: string;
  modelId: string;
  outputFormat: string;
  languageCode?: string;
}

export interface ElevenLabsSpeech {
  audioBase64: string;
  mimeType: string;
}

const API_BASE_URL = 'https://api.elevenlabs.io/v1';
const MAX_TTS_CHARS = 180;

export class ElevenLabsTtsService {
  async synthesize(text: string, options: ElevenLabsTtsOptions): Promise<ElevenLabsSpeech | null> {
    const apiKey = process.env.ELEVENLABS_API_KEY;
    if (!apiKey) {
      logger.warn('tts.elevenlabs.missing_api_key');
      return null;
    }

    if (!options.voiceId) {
      logger.warn('tts.elevenlabs.missing_voice_id');
      return null;
    }

    const inputText = trimForShortCue(text);
    if (!inputText) return null;

    try {
      const url = new URL(`${API_BASE_URL}/text-to-speech/${options.voiceId}`);
      url.searchParams.set('output_format', options.outputFormat);

      const res = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'xi-api-key': apiKey,
        },
        body: JSON.stringify({
          text: inputText,
          model_id: options.modelId,
          language_code: options.languageCode ?? 'pt',
          voice_settings: {
            stability: 0.58,
            similarity_boost: 0.78,
            style: 0.18,
            use_speaker_boost: true,
          },
        }),
      });

      if (!res.ok) {
        const body = await res.text().catch(() => '');
        throw new Error(`ElevenLabs TTS failed: ${res.status} ${body.slice(0, 300)}`);
      }

      const audio = Buffer.from(await res.arrayBuffer());
      return {
        audioBase64: audio.toString('base64'),
        mimeType: mimeTypeForOutput(options.outputFormat),
      };
    } catch (err) {
      logger.warn('tts.elevenlabs.failed', {
        err: err instanceof Error ? err.message : String(err),
      });
      return null;
    }
  }
}

function trimForShortCue(text: string): string {
  const normalized = text.replace(/\s+/g, ' ').trim();
  if (normalized.length <= MAX_TTS_CHARS) return normalized;

  const sentenceEnd = normalized.slice(0, MAX_TTS_CHARS).search(/[.!?](?!.*[.!?])/);
  if (sentenceEnd > 80) return normalized.slice(0, sentenceEnd + 1).trim();

  const hardCut = normalized.slice(0, MAX_TTS_CHARS);
  const lastSpace = hardCut.lastIndexOf(' ');
  return `${hardCut.slice(0, lastSpace > 80 ? lastSpace : MAX_TTS_CHARS).trim()}.`;
}

function mimeTypeForOutput(outputFormat: string): string {
  if (outputFormat.startsWith('wav_')) return 'audio/wav';
  if (outputFormat.startsWith('pcm_')) return 'audio/pcm';
  return 'audio/mpeg';
}
