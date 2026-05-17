import { GeminiLiveSession } from './gemini-live.service';
import { logger } from '@shared/logger/logger';

/**
 * One-shot TTS via Gemini Live: abre WS, manda texto, recebe áudio,
 * fecha. Substitui ElevenLabs/Google TTS pra cues automáticos da run.
 *
 * Saída: WAV PCM 24kHz 16-bit mono encoded em base64. Browser/Flutter
 * tocam nativamente.
 *
 * Não é interativo (não recebe audio do user). Pra chat com user falar,
 * usar GeminiLiveSession direto via WS proxy.
 */
export class GeminiLiveTtsService {
  /** Mapa coachVoiceId (do app) → voz prebuilt do Gemini Live. */
  private readonly voiceMap: Record<string, string> = {
    'coach-bruno': 'Charon',  // voz masculina firme
    'coach-clara': 'Aoede',   // voz feminina calorosa
    'coach-luna': 'Kore',     // voz feminina mais cool/neutra
  };

  /**
   * Sintetiza áudio. Falha silenciosa → retorna null e use-case continua
   * com texto (sem áudio). Não pode bloquear o cue por TTS travar.
   *
   * Timeout interno: 12s (cues curtos devem responder em <5s; 12s é
   * margem pra ondas de cold-start).
   */
  async synthesize(
    text: string,
    opts: { voiceId?: string } = {},
  ): Promise<{ audioBase64: string; mimeType: string } | null> {
    if (!text.trim()) return null;
    if (!process.env['GEMINI_API_KEY']?.trim()) {
      logger.warn('gemini.live_tts.skipped_no_key');
      return null;
    }

    const voice = opts.voiceId
      ? this.voiceMap[opts.voiceId] ?? 'Charon'
      : 'Charon';

    const chunks: Buffer[] = [];
    let sessionMimeType = 'audio/pcm;rate=24000';
    let resolveDone: (() => void) | null = null;
    let rejectDone: ((err: Error) => void) | null = null;
    const done = new Promise<void>((res, rej) => {
      resolveDone = res;
      rejectDone = rej;
    });

    const session = new GeminiLiveSession({
      config: {
        // Modelo Live com áudio nativo. Mantém em sync com gemini-live.service
        // default. Outputmodality precisa ser AUDIO pra TTS funcionar.
        responseModalities: ['AUDIO'],
        voice,
        systemInstruction:
          'Você é o coach AI do runnin falando ao vivo durante uma corrida. ' +
          'Fale o texto recebido como se estivesse passando a mensagem AO VIVO ' +
          'pro atleta correndo — tom direto, energético quando apropriado, ' +
          'sem floreios. PT-BR. Não acrescente nem reformule — fale o texto.',
      },
      onMessage: (msg) => {
        if (msg.kind !== 'content') return;
        const parts = msg.serverContent.modelTurn?.parts ?? [];
        for (const p of parts) {
          if (p.inlineData?.data) {
            chunks.push(Buffer.from(p.inlineData.data, 'base64'));
            if (p.inlineData.mimeType) sessionMimeType = p.inlineData.mimeType;
          }
        }
        if (msg.serverContent.turnComplete) resolveDone?.();
      },
      onClose: (code) => {
        if (chunks.length === 0) {
          rejectDone?.(new Error(`Live session closed code=${code} with 0 chunks`));
        } else {
          resolveDone?.();
        }
      },
    });

    try {
      await session.open();
      session.sendText(text);

      await Promise.race([
        done,
        new Promise<void>((_, rej) =>
          setTimeout(() => rej(new Error('gemini_live_tts_timeout_12s')), 12000),
        ),
      ]);

      session.close();

      if (chunks.length === 0) return null;
      const pcm = Buffer.concat(chunks);
      const sampleRate = parseSampleRate(sessionMimeType) ?? 24000;
      const wav = pcmToWav(pcm, sampleRate);
      return {
        audioBase64: wav.toString('base64'),
        mimeType: 'audio/wav',
      };
    } catch (err) {
      logger.warn('gemini.live_tts.failed', {
        err: err instanceof Error ? err.message : String(err),
        textLen: text.length,
        voice,
      });
      try {
        session.close();
      } catch {}
      return null;
    }
  }
}

/** Tenta extrair sampleRate de `audio/pcm;rate=24000`. */
function parseSampleRate(mimeType: string): number | undefined {
  const m = mimeType.match(/rate=(\d+)/);
  return m ? Number(m[1]) : undefined;
}

/**
 * Wrap PCM 16-bit signed little-endian mono em header WAV (RIFF). 44
 * bytes de header + payload. Permite tocar direto no browser/Flutter
 * sem precisar do AudioContext decodificar PCM cru.
 */
function pcmToWav(pcm: Buffer, sampleRate: number): Buffer {
  const numChannels = 1;
  const bitsPerSample = 16;
  const byteRate = sampleRate * numChannels * (bitsPerSample / 8);
  const blockAlign = numChannels * (bitsPerSample / 8);
  const dataSize = pcm.length;
  const fileSize = 36 + dataSize;

  const header = Buffer.alloc(44);
  header.write('RIFF', 0);
  header.writeUInt32LE(fileSize, 4);
  header.write('WAVE', 8);
  header.write('fmt ', 12);
  header.writeUInt32LE(16, 16);              // subchunk1Size
  header.writeUInt16LE(1, 20);               // audioFormat = PCM
  header.writeUInt16LE(numChannels, 22);
  header.writeUInt32LE(sampleRate, 24);
  header.writeUInt32LE(byteRate, 28);
  header.writeUInt16LE(blockAlign, 32);
  header.writeUInt16LE(bitsPerSample, 34);
  header.write('data', 36);
  header.writeUInt32LE(dataSize, 40);

  return Buffer.concat([header, pcm]);
}
