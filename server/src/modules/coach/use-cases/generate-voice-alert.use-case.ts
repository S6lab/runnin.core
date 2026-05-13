import { getAsyncLLM } from '@shared/infra/llm/llm.factory';
import { GoogleTtsService } from '@shared/infra/tts/google-tts.service';
import { ElevenLabsTtsService } from '@shared/infra/tts/elevenlabs-tts.service';
import { CoachConfigService } from './coach-config.service';
import { logger } from '@shared/logger/logger';

const SYSTEM_PROMPT = `Você é o Coach.AI do runnin: um personal trainer de corrida experiente ao lado do corredor.
Gere alertas de voz ultra-curtos durante a corrida em português brasileiro.
Fale diretamente com o corredor, de forma clara e encorajadora.
Tom humano, firme e motivador. Máximo 1-2 frases muito curtas. Sem emojis.
A resposta deve caber em até 10 segundos de áudio.`;

export type VoiceAlertType =
  | 'pace_too_fast'
  | 'pace_too_slow'
  | 'pace_on_target'
  | 'hr_zone_high'
  | 'hr_zone_low'
  | 'hr_zone_optimal'
  | 'distance_milestone'
  | 'time_milestone'
  | 'encouragement'
  | 'halfway_point'
  | 'final_push';

export interface GenerateVoiceAlertInput {
  alertType: VoiceAlertType;
  context: {
    currentPace?: string;
    targetPace?: string;
    currentBpm?: number;
    targetBpmZone?: { min: number; max: number };
    distanceKm?: number;
    targetDistanceKm?: number;
    elapsedMinutes?: number;
    sessionType?: string;
  };
}

export interface VoiceAlertResult {
  alertId: string;
  alertType: VoiceAlertType;
  text: string;
  audioBase64?: string;
  audioMimeType?: string;
  generatedAt: string;
}

export class GenerateVoiceAlertUseCase {
  private llm = getAsyncLLM();
  private googleTts = new GoogleTtsService();
  private elevenLabsTts = new ElevenLabsTtsService();
  private configService = new CoachConfigService();

  async execute(userId: string, input: GenerateVoiceAlertInput): Promise<VoiceAlertResult> {
    const alertId = `alert_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`;

    try {
      // Generate alert text using LLM for dynamic, contextual feedback
      const alertText = await this.generateAlertText(input);

      // Generate TTS audio
      const config = await this.configService.getConfig();
      let audioBase64: string | undefined;
      let audioMimeType: string | undefined;

      if (config.ttsEnabled) {
        const audio = await this.synthesizeAlert(alertText, config);
        if (audio) {
          audioBase64 = audio.audioBase64;
          audioMimeType = audio.mimeType;
        }
      }

      return {
        alertId,
        alertType: input.alertType,
        text: alertText,
        audioBase64,
        audioMimeType,
        generatedAt: new Date().toISOString(),
      };
    } catch (err) {
      logger.error('coach.voice_alert.failed', { userId, input, err });
      throw err;
    }
  }

  private async generateAlertText(input: GenerateVoiceAlertInput): Promise<string> {
    const { alertType, context } = input;

    // Build context-aware prompt
    let prompt = '';

    switch (alertType) {
      case 'pace_too_fast':
        prompt = `O corredor está muito rápido. Pace atual: ${context.currentPace ?? 'N/A'}/km, pace alvo: ${context.targetPace ?? 'N/A'}/km.
Dê um alerta curto para desacelerar um pouco. Máximo 2 frases curtas.`;
        break;

      case 'pace_too_slow':
        prompt = `O corredor está muito devagar. Pace atual: ${context.currentPace ?? 'N/A'}/km, pace alvo: ${context.targetPace ?? 'N/A'}/km.
Dê um alerta curto para acelerar um pouco. Máximo 2 frases curtas.`;
        break;

      case 'pace_on_target':
        prompt = `O corredor está no pace perfeito. Pace atual: ${context.currentPace ?? 'N/A'}/km, pace alvo: ${context.targetPace ?? 'N/A'}/km.
Dê um feedback positivo curto. Máximo 2 frases curtas.`;
        break;

      case 'hr_zone_high':
        prompt = `Frequência cardíaca alta: ${context.currentBpm ?? 'N/A'} bpm. Zona alvo: ${context.targetBpmZone?.min ?? 'N/A'}-${context.targetBpmZone?.max ?? 'N/A'} bpm.
Dê um alerta curto para reduzir a intensidade. Máximo 2 frases curtas.`;
        break;

      case 'hr_zone_low':
        prompt = `Frequência cardíaca baixa: ${context.currentBpm ?? 'N/A'} bpm. Zona alvo: ${context.targetBpmZone?.min ?? 'N/A'}-${context.targetBpmZone?.max ?? 'N/A'} bpm.
Dê um alerta curto para aumentar a intensidade um pouco. Máximo 2 frases curtas.`;
        break;

      case 'hr_zone_optimal':
        prompt = `Frequência cardíaca ótima: ${context.currentBpm ?? 'N/A'} bpm na zona alvo.
Dê um feedback positivo curto. Máximo 2 frases curtas.`;
        break;

      case 'distance_milestone':
        prompt = `O corredor completou ${context.distanceKm ?? 0}km de ${context.targetDistanceKm ?? 0}km.
Dê um feedback motivador curto sobre o progresso. Máximo 2 frases curtas.`;
        break;

      case 'time_milestone':
        prompt = `O corredor completou ${context.elapsedMinutes ?? 0} minutos de treino.
Dê um feedback motivador curto. Máximo 2 frases curtas.`;
        break;

      case 'halfway_point':
        prompt = `O corredor está na metade do treino (${context.distanceKm ?? 0}km de ${context.targetDistanceKm ?? 0}km).
Dê um feedback motivador curto. Máximo 2 frases curtas.`;
        break;

      case 'final_push':
        prompt = `Falta pouco para terminar! ${context.distanceKm ?? 0}km de ${context.targetDistanceKm ?? 0}km completos.
Dê um incentivo final forte e curto. Máximo 2 frases curtas.`;
        break;

      case 'encouragement':
        prompt = `Sessão de ${context.sessionType ?? 'corrida'} em progresso.
Dê um incentivo geral curto e motivador. Máximo 2 frases curtas.`;
        break;

      default:
        prompt = 'Dê um feedback geral positivo para o corredor. Máximo 2 frases curtas.';
    }

    const alertText = await this.llm.generate(prompt, {
      systemPrompt: SYSTEM_PROMPT,
      maxTokens: 100,
      temperature: 0.7,
    });

    return alertText.trim();
  }

  private async synthesizeAlert(
    text: string,
    config: ReturnType<CoachConfigService['getConfig']> extends Promise<infer T> ? T : never,
  ): Promise<{ audioBase64: string; mimeType: string } | null> {
    try {
      if (config.ttsProvider === 'elevenlabs') {
        const voiceId = config.elevenLabsVoiceIds['coach-bruno'] || '';
        if (!voiceId) {
          logger.warn('coach.voice_alert.elevenlabs_voice_missing');
          return null;
        }

        return await this.elevenLabsTts.synthesize(text, {
          voiceId,
          modelId: config.elevenLabsModelId,
          outputFormat: config.elevenLabsOutputFormat,
          languageCode: 'pt',
        });
      }

      // Default to Google TTS
      return await this.googleTts.synthesize(text, {
        voiceName: config.ttsVoiceName,
        languageCode: config.ttsLanguageCode,
        speakingRate: config.ttsSpeakingRate,
      });
    } catch (err) {
      logger.warn('coach.voice_alert.tts_failed', {
        err: err instanceof Error ? err.message : String(err),
      });
      return null;
    }
  }
}
