import { z } from 'zod';
import { getRealtimeLLM } from '@shared/infra/llm/llm.factory';
import { formatRunningKnowledgeContext } from '@shared/knowledge/running/running-knowledge';
import { ElevenLabsTtsService } from '@shared/infra/tts/elevenlabs-tts.service';
import { GoogleTtsService } from '@shared/infra/tts/google-tts.service';
import { GeminiLiveTtsService } from '@shared/infra/llm/gemini-live-tts.service';
import { buildLiveCoachPrompt, getKnobs, isInDndWindow } from '@shared/infra/llm/prompts';
import { CoachConfigService } from './coach-config.service';
import { CoachRuntimeContextService } from './coach-runtime-context.service';
import { resolveCoachVoicePreset } from './coach-voice-presets';
import { CoachMessageLogRepository } from '../domain/coach-message-log.repository';
import { CoachMessageLog } from '../domain/coach-message-log.entity';
import { FirestoreCoachMessageLogRepository } from '../infra/firestore-coach-message-log.repository';
import { logger } from '@shared/logger/logger';
import { randomUUID } from 'crypto';

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

export interface CoachCueSkipped {
  skipped: true;
  reason: 'frequency' | 'dnd' | 'silent';
}

export type CoachGenerateResult = CoachCueResponse | CoachCueSkipped;

export function isCueSkipped(result: CoachGenerateResult): result is CoachCueSkipped {
  return (result as CoachCueSkipped).skipped === true;
}

export class CoachMessageUseCase {
  private llm = getRealtimeLLM();
  private googleTts = new GoogleTtsService();
  private elevenLabsTts = new ElevenLabsTtsService();
  // Gemini Live TTS é o source primário (mesmo motor do chat ao vivo).
  // ElevenLabs/Google ficam como fallbacks pra resiliência.
  private liveTts = new GeminiLiveTtsService();
  private config = new CoachConfigService();
  private runtime = new CoachRuntimeContextService();
  private messageLog: CoachMessageLogRepository = new FirestoreCoachMessageLogRepository();

  async generate(ctx: CoachContext, userId: string): Promise<CoachGenerateResult> {
    const [config, runtime, knobs] = await Promise.all([
      this.config.getConfig(),
      this.runtime.getContext(userId),
      getKnobs(),
    ]);

    const decision = applyDecisionLayer(ctx, runtime.profile, knobs);
    if (decision) return decision;

    const knowledgeContext = await formatRunningKnowledgeContext(
      `${runtime.profile?.goal ?? ''} ${runtime.profile?.level ?? ''} ${ctx.event} corrida ${ctx.runType ?? ''} pace ${ctx.targetPaceMinKm ?? ''} bpm ${ctx.bpm ?? ''} ${ctx.question ?? ''}`,
      2,
    );

    const built = await buildLiveCoachPrompt({
      profile: runtime.profile,
      runtimeContextJson: JSON.stringify(runtime, null, 2),
      ctx,
      ragContext: knowledgeContext,
      legacyLivePrompt: config.livePrompt,
    });

    const rawText = await this.llm.generate(built.userPrompt, {
      systemPrompt: built.systemPrompt,
      maxTokens: built.maxTokens,
      temperature: built.temperature,
    });
    const text = cleanCueText(rawText);
    const voicePreset = resolveCoachVoicePreset(runtime.profile?.coachVoiceId);
    let audio = null as { audioBase64: string; mimeType: string } | null;

    if (config.ttsEnabled) {
      // Cascata: Gemini Live (primário) → ElevenLabs → Google TTS.
      // Live falhar (timeout/quota) cai pros legados pra não ficar mudo.
      audio = await this.liveTts.synthesize(text, {
        voiceId: voicePreset?.id ?? 'coach-bruno',
      });

      if (!audio && config.ttsProvider === 'elevenlabs') {
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
      }

      if (!audio) {
        audio = await this.googleTts.synthesize(text, {
          voiceName: voicePreset?.googleVoiceName ?? config.ttsVoiceName,
          languageCode: voicePreset?.languageCode ?? config.ttsLanguageCode,
          speakingRate: voicePreset?.speakingRate ?? config.ttsSpeakingRate,
        });
      }
    }

    if (ctx.runId && ctx.event !== 'question') {
      const log: CoachMessageLog = {
        id: randomUUID(),
        runId: ctx.runId,
        userId,
        author: 'coach',
        event: ctx.event,
        text,
        audioMimeType: audio?.mimeType,
        kmAtTime: ctx.kmReached ?? (ctx.distanceM / 1000),
        paceAtTime: ctx.currentPaceMinKm ? ctx.currentPaceMinKm.toFixed(2) : undefined,
        bpmAtTime: ctx.bpm,
        promptVersion: built.version,
        promptSource: built.source,
        createdAt: new Date().toISOString(),
      };
      this.messageLog.save(log).catch(err => {
        logger.warn('coach.message_log.save_failed', { runId: ctx.runId, err: String(err) });
      });
    }

    return {
      text,
      audioBase64: audio?.audioBase64,
      audioMimeType: audio?.mimeType,
    };
  }

  async listForRun(userId: string, runId: string): Promise<CoachMessageLog[]> {
    return this.messageLog.listByRun(userId, runId);
  }
}

function applyDecisionLayer(
  ctx: CoachContext,
  profile: { coachMessageFrequency?: string; dndWindow?: { start: string; end: string } } | null | undefined,
  knobs: { respectMessageFrequency: boolean; respectDndWindow: boolean },
): CoachCueSkipped | null {
  if (knobs.respectMessageFrequency) {
    const freq = profile?.coachMessageFrequency;
    if (freq === 'silent') return { skipped: true, reason: 'silent' };
    if (ctx.event === 'km_reached') {
      const km = ctx.kmReached ?? 0;
      if (freq === 'alerts_only') return { skipped: true, reason: 'frequency' };
      if (freq === 'per_2km' && km > 0 && km % 2 !== 0) return { skipped: true, reason: 'frequency' };
    }
    if (ctx.event === 'pace_alert' && freq === 'silent') return { skipped: true, reason: 'silent' };
  }

  if (knobs.respectDndWindow && profile?.dndWindow && isInDndWindow(profile.dndWindow)) {
    if (ctx.event !== 'pace_alert' && ctx.event !== 'finish') {
      return { skipped: true, reason: 'dnd' };
    }
  }

  return null;
}

function cleanCueText(text: string): string {
  return text
    .replace(/```[\s\S]*?```/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}
