import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { logger } from '@shared/logger/logger';

export const DEFAULT_LIVE_COACH_PROMPT = `Você é o Coach.AI do runnin: um personal trainer de corrida experiente, presente e direto.
Fale sempre em português brasileiro, diretamente com o corredor.
Use todo o contexto disponível: perfil, objetivo, plano, histórico recente, sessão atual, pace e frequência cardíaca quando houver.
Antes da corrida, prepare o atleta para executar o treino do dia com foco claro.
Durante a corrida, guie como um treinador ao lado: incentive, corrija pace, observe BPM quando disponível e ajuste a orientação ao objetivo.
Se o BPM estiver alto para o esforço esperado, reduza intensidade e priorize segurança.
Se o pace estiver fora do alvo, corrija com uma ação simples para o próximo minuto.
Tom humano, firme, motivador e prático. Máximo 2 frases curtas. Sem emojis. A resposta deve caber em até 10 segundos de áudio.`;

export interface CoachPromptConfig {
  livePrompt: string;
  ttsEnabled: boolean;
  ttsProvider: 'google' | 'elevenlabs';
  ttsVoiceName: string;
  ttsLanguageCode: string;
  ttsSpeakingRate: number;
  elevenLabsModelId: string;
  elevenLabsOutputFormat: string;
  elevenLabsVoiceIds: Record<string, string>;
}

const DEFAULT_CONFIG: CoachPromptConfig = {
  livePrompt: DEFAULT_LIVE_COACH_PROMPT,
  ttsEnabled: process.env.GOOGLE_TTS_ENABLED !== 'false',
  ttsProvider: process.env.TTS_PROVIDER === 'elevenlabs' ? 'elevenlabs' : 'google',
  ttsVoiceName: process.env.GOOGLE_TTS_VOICE_NAME ?? 'pt-BR-Neural2-B',
  ttsLanguageCode: process.env.GOOGLE_TTS_LANGUAGE_CODE ?? 'pt-BR',
  ttsSpeakingRate: Number(process.env.GOOGLE_TTS_SPEAKING_RATE ?? 1.08),
  elevenLabsModelId: process.env.ELEVENLABS_MODEL_ID ?? 'eleven_multilingual_v2',
  elevenLabsOutputFormat: process.env.ELEVENLABS_OUTPUT_FORMAT ?? 'mp3_44100_128',
  elevenLabsVoiceIds: {
    'coach-bruno': process.env.ELEVENLABS_VOICE_BRUNO_ID ?? process.env.ELEVENLABS_VOICE_ID ?? '',
    'coach-clara': process.env.ELEVENLABS_VOICE_CLARA_ID ?? '',
    'coach-luna': process.env.ELEVENLABS_VOICE_LUNA_ID ?? '',
  },
};

export class CoachConfigService {
  async getConfig(): Promise<CoachPromptConfig> {
    try {
      const doc = await getFirestore().collection('app_config').doc('coach').get();
      if (!doc.exists) return DEFAULT_CONFIG;

      const data = doc.data() as Record<string, unknown>;
      return {
        livePrompt: stringValue(data['livePrompt']) || DEFAULT_CONFIG.livePrompt,
        ttsEnabled: booleanValue(data['ttsEnabled'], DEFAULT_CONFIG.ttsEnabled),
        ttsProvider: data['ttsProvider'] === 'elevenlabs' ? 'elevenlabs' : 'google',
        ttsVoiceName: stringValue(data['ttsVoiceName']) || DEFAULT_CONFIG.ttsVoiceName,
        ttsLanguageCode: stringValue(data['ttsLanguageCode']) || DEFAULT_CONFIG.ttsLanguageCode,
        ttsSpeakingRate: numberValue(data['ttsSpeakingRate'], DEFAULT_CONFIG.ttsSpeakingRate),
        elevenLabsModelId: stringValue(data['elevenLabsModelId']) || DEFAULT_CONFIG.elevenLabsModelId,
        elevenLabsOutputFormat: stringValue(data['elevenLabsOutputFormat']) || DEFAULT_CONFIG.elevenLabsOutputFormat,
        elevenLabsVoiceIds: {
          ...DEFAULT_CONFIG.elevenLabsVoiceIds,
          ...recordStringValues(data['elevenLabsVoiceIds']),
        },
      };
    } catch (err) {
      logger.warn('coach.config.unavailable', {
        err: err instanceof Error ? err.message : String(err),
      });
      return DEFAULT_CONFIG;
    }
  }
}

function stringValue(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim().length > 0 ? value.trim() : undefined;
}

function booleanValue(value: unknown, fallback: boolean): boolean {
  return typeof value === 'boolean' ? value : fallback;
}

function numberValue(value: unknown, fallback: number): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
}

function recordStringValues(value: unknown): Record<string, string> {
  if (!value || typeof value !== 'object') return {};
  return Object.fromEntries(
    Object.entries(value as Record<string, unknown>)
      .filter(([, item]) => typeof item === 'string' && item.trim().length > 0)
      .map(([key, item]) => [key, (item as string).trim()]),
  );
}
