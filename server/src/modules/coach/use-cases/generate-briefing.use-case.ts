import { getAsyncLLM } from '@shared/infra/llm/llm.factory';
import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { GoogleTtsService } from '@shared/infra/tts/google-tts.service';
import { ElevenLabsTtsService } from '@shared/infra/tts/elevenlabs-tts.service';
import { CoachConfigService } from './coach-config.service';
import { logger } from '@shared/logger/logger';
import { formatRunningKnowledgeContext } from '@shared/knowledge/running/running-knowledge';
import { PlanSession } from '@modules/plans/domain/plan.entity';

const SYSTEM_PROMPT = `Você é o Coach.AI do runnin: um personal trainer de corrida experiente.
Gere briefings pré-treino curtos e motivadores em português brasileiro.
Fale diretamente com o corredor, de forma clara e encorajadora.
Foco: objetivo da sessão, ritmo alvo, zonas cardíacas esperadas, e dicas práticas.
Tom humano, firme e motivador. Máximo 3 parágrafos curtos. Sem emojis.`;

export interface GenerateBriefingInput {
  sessionType: string;
  distanceKm: number;
  targetPace?: string;
  planSessionId?: string;
  sessionNotes?: string;
}

export interface BriefingResult {
  briefingId: string;
  text: string;
  audioBase64?: string;
  audioMimeType?: string;
  generatedAt: string;
}

export class GenerateBriefingUseCase {
  private llm = getAsyncLLM();
  private googleTts = new GoogleTtsService();
  private elevenLabsTts = new ElevenLabsTtsService();
  private configService = new CoachConfigService();

  async execute(userId: string, input: GenerateBriefingInput): Promise<BriefingResult> {
    const briefingId = `briefing_${Date.now()}_${Math.random().toString(36).slice(2, 9)}`;

    try {
      // Fetch plan session details if provided
      let planSession: PlanSession | null = null;
      if (input.planSessionId) {
        planSession = await this.fetchPlanSession(userId, input.planSessionId);
      }

      // Generate briefing text
      const briefingText = await this.generateBriefingText(input, planSession);

      // Generate TTS audio
      const config = await this.configService.getConfig();
      let audioBase64: string | undefined;
      let audioMimeType: string | undefined;

      if (config.ttsEnabled) {
        const audio = await this.synthesizeBriefing(briefingText, config);
        if (audio) {
          audioBase64 = audio.audioBase64;
          audioMimeType = audio.mimeType;
        }
      }

      const result: BriefingResult = {
        briefingId,
        text: briefingText,
        audioBase64,
        audioMimeType,
        generatedAt: new Date().toISOString(),
      };

      // Store briefing in Firestore
      await getFirestore()
        .collection(`users/${userId}/briefings`)
        .doc(briefingId)
        .set(result);

      return result;
    } catch (err) {
      logger.error('coach.briefing.failed', { userId, input, err });
      throw err;
    }
  }

  private async generateBriefingText(
    input: GenerateBriefingInput,
    planSession: PlanSession | null,
  ): Promise<string> {
    const knowledgeContext = await formatRunningKnowledgeContext(
      `${input.sessionType} corrida ${input.distanceKm}km pace ${input.targetPace ?? ''}`,
      3,
    );

    const sessionNotes = input.sessionNotes || planSession?.notes || '';
    const targetPace = input.targetPace || planSession?.targetPace || '';

    const prompt = `Prepare um briefing pré-treino para esta sessão:
- Tipo: ${input.sessionType}
- Distância: ${input.distanceKm}km
${targetPace ? `- Pace alvo: ${targetPace}/km` : ''}
${sessionNotes ? `- Notas do plano: ${sessionNotes}` : ''}

Inclua no briefing:
1. Objetivo principal da sessão (1-2 frases)
2. Orientação sobre ritmo e intensidade (considere zonas cardíacas se aplicável)
3. Dica prática ou foco técnico para executar bem

Base de conhecimento:
${knowledgeContext}`;

    const briefing = await this.llm.generate(prompt, {
      systemPrompt: SYSTEM_PROMPT,
      maxTokens: 350,
    });

    return briefing.trim();
  }

  private async synthesizeBriefing(
    text: string,
    config: ReturnType<CoachConfigService['getConfig']> extends Promise<infer T> ? T : never,
  ): Promise<{ audioBase64: string; mimeType: string } | null> {
    try {
      if (config.ttsProvider === 'elevenlabs') {
        const voiceId = config.elevenLabsVoiceIds['coach-bruno'] || '';
        if (!voiceId) {
          logger.warn('coach.briefing.elevenlabs_voice_missing');
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
      logger.warn('coach.briefing.tts_failed', {
        err: err instanceof Error ? err.message : String(err),
      });
      return null;
    }
  }

  private async fetchPlanSession(userId: string, planSessionId: string): Promise<PlanSession | null> {
    try {
      // planSessionId format: planId:sessionId
      const [planId, sessionId] = planSessionId.split(':');
      if (!planId || !sessionId) return null;

      const planDoc = await getFirestore()
        .collection(`users/${userId}/plans`)
        .doc(planId)
        .get();

      if (!planDoc.exists) return null;

      const plan = planDoc.data() as { weeks?: Array<{ sessions: PlanSession[] }> };
      if (!plan.weeks) return null;

      for (const week of plan.weeks) {
        const session = week.sessions.find((s) => s.id === sessionId);
        if (session) return session;
      }

      return null;
    } catch (err) {
      logger.warn('coach.briefing.plan_session_fetch_failed', { userId, planSessionId, err });
      return null;
    }
  }
}
