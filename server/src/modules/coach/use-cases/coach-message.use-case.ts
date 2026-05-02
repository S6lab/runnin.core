import { z } from 'zod';
import { getRealtimeLLM } from '@shared/infra/llm/llm.factory';
import { formatRunningKnowledgeContext } from '@shared/knowledge/running/running-knowledge';
import { ElevenLabsTtsService } from '@shared/infra/tts/elevenlabs-tts.service';
import { GoogleTtsService } from '@shared/infra/tts/google-tts.service';
import { CoachConfigService } from './coach-config.service';
import { CoachRuntimeContext, CoachRuntimeContextService } from './coach-runtime-context.service';
import { resolveCoachVoicePreset } from './coach-voice-presets';

const OptionalNumberSchema = z.preprocess(
  value => value === null ? undefined : value,
  z.number().optional(),
);

export const CoachContextSchema = z.object({
  runId: z.string().optional(),
  event: z.enum(['pre_run', 'km_reached', 'pace_alert', 'question', 'start', 'finish']),
  runType: z.string().optional(),
  currentPaceMinKm: z.number(),
  targetPaceMinKm: OptionalNumberSchema,
  targetDistance: z.string().optional(),
  distanceM: z.number(),
  elapsedS: z.number(),
  bpm: OptionalNumberSchema,
  kmReached: OptionalNumberSchema,
  question: z.string().optional(),
});

export type CoachContext = z.infer<typeof CoachContextSchema>;

export interface CoachCueResponse {
  text: string;
  audioBase64?: string;
  audioMimeType?: string;
}

async function buildPrompt(ctx: CoachContext, runtime: CoachRuntimeContext): Promise<string> {
  const pace = ctx.currentPaceMinKm.toFixed(2);
  const target = ctx.targetPaceMinKm?.toFixed(2) ?? 'livre';
  const dist = (ctx.distanceM / 1000).toFixed(2);
  const elapsed = `${Math.floor(ctx.elapsedS / 60)}min`;

  const base = `Corrida atual: tipo ${ctx.runType ?? 'nao informado'}, ${dist}km rodados, pace atual ${pace}/km (alvo: ${target}/km), tempo ${elapsed}${ctx.bpm ? `, BPM ${ctx.bpm}` : ''}.`;

  const eventPrompt = (() => {
    switch (ctx.event) {
      case 'pre_run': return `O corredor quer iniciar uma corrida do tipo ${ctx.runType ?? 'livre'}. Prepare o atleta com foco no objetivo, no plano atual e no cuidado com intensidade.`;
      case 'km_reached': return `${base} Acabou de completar o km ${ctx.kmReached}. Dê feedback rapido de personal trainer sobre o pace e uma acao simples.`;
      case 'pace_alert': return `${base} Pace desviou do plano. Corrija o corredor como um treinador faria, com firmeza e motivacao.`;
      case 'start': return `Corredor iniciando treino. Pace alvo: ${target}/km. Dê uma frase de largada de personal trainer, com foco claro.`;
      case 'finish': return `${base} Corrida finalizada! Dê parabens e um insight rapido do desempenho, como treinador.`;
      case 'question': return `${base} O corredor perguntou: "${ctx.question}". Responda brevemente.`;
      default: return base;
    }
  })();

  const knowledgeContext = await formatRunningKnowledgeContext(
    `${runtime.profile?.goal ?? ''} ${runtime.profile?.level ?? ''} ${ctx.event} corrida ${ctx.runType ?? ''} pace ${target} bpm ${ctx.bpm ?? ''} ${ctx.question ?? ''}`,
    2,
  );

  const runTimeEvents = ['km_reached', 'pace_alert', 'start', 'finish'];
  const isRunTime = runTimeEvents.includes(ctx.event);

  const rules = isRunTime
    ? `Regras para esta resposta:\n- Use o contexto completo para orientar a decisão.\n- Se houver frequência cardíaca, considere segurança e ajuste de intensidade.\n- Se houver plano ou objetivo, conecte a orientação ao objetivo.\n- Responda em até 2 frases curtas, cabendo em até 10 segundos de audio.`
    : `Regras para esta resposta:\n- Use o contexto completo para orientar a decisão.\n- Se houver frequência cardíaca, considere segurança e ajuste de intensidade.\n- Se houver plano ou objetivo, conecte a orientação ao objetivo.\n- Fora da corrida, a resposta pode ser mais detalhada: até 4 frases curtas, cabendo em até 30 segundos de audio.`;

  return `${eventPrompt}\n\nContexto do atleta e plano:\n${JSON.stringify(runtime, null, 2)}\n\n${rules}\n\nBase de conhecimento:\n${knowledgeContext}`;
}

export class CoachMessageUseCase {
  private llm = getRealtimeLLM();
  private googleTts = new GoogleTtsService();
  private elevenLabsTts = new ElevenLabsTtsService();
  private config = new CoachConfigService();
  private runtime = new CoachRuntimeContextService();

  async generate(ctx: CoachContext, userId: string): Promise<CoachCueResponse> {
    const [config, runtime] = await Promise.all([
      this.config.getConfig(),
      this.runtime.getContext(userId),
    ]);
    const prompt = await buildPrompt(ctx, runtime);
    const runTimeEvents = ['km_reached', 'pace_alert', 'start', 'finish'];
    const isRunTime = runTimeEvents.includes(ctx.event);

    const systemPrompt = isRunTime
      ? config.livePrompt
      : `${config.livePrompt}\nFora da corrida, responda em até 4 frases curtas, conectando contexto e objetivo; pode ser mais detalhado (até 30 segundos de áudio).`;

    const maxTokens = isRunTime ? 80 : 1024;
    const rawText = await this.llm.generate(prompt, {
      systemPrompt,
      maxTokens,
      temperature: 0.75,
    });
    const text = cleanCueText(rawText);
    const voicePreset = resolveCoachVoicePreset(runtime.profile?.coachVoiceId);
    let audio = null as { audioBase64: string; mimeType: string } | null;
    if (config.ttsEnabled) {
      if (config.ttsProvider === 'elevenlabs') {
        const voiceId =
          config.elevenLabsVoiceIds[voicePreset?.id ?? 'coach-bruno'] ||
          config.elevenLabsVoiceIds['coach-bruno'] ||
          '';
        audio = await this.elevenLabsTts.synthesize(text, {
          voiceId,
          modelId: config.elevenLabsModelId,
          outputFormat: config.elevenLabsOutputFormat,
          languageCode: 'pt',
        });

        if (!audio) {
          // fallback to Google TTS when ElevenLabs fails (missing voice id or error)
          audio = await this.googleTts.synthesize(text, {
            voiceName: voicePreset?.googleVoiceName ?? config.ttsVoiceName,
            languageCode: voicePreset?.languageCode ?? config.ttsLanguageCode,
            speakingRate: voicePreset?.speakingRate ?? config.ttsSpeakingRate,
          });
        }
      } else {
        audio = await this.googleTts.synthesize(text, {
          voiceName: voicePreset?.googleVoiceName ?? config.ttsVoiceName,
          languageCode: voicePreset?.languageCode ?? config.ttsLanguageCode,
          speakingRate: voicePreset?.speakingRate ?? config.ttsSpeakingRate,
        });
      }
    }

    return {
      text,
      audioBase64: audio?.audioBase64,
      audioMimeType: audio?.mimeType,
    };
  }
}

function cleanCueText(text: string): string {
  return text
    .replace(/```[\s\S]*?```/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}
