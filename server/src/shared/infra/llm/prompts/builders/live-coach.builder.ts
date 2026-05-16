import { UserProfile } from '@modules/users/domain/user.entity';
import { getPromptConfig } from '../config-store';
import { renderTemplate } from '../render';
import { resolvePersonaTone } from '../persona/resolver';
import { formatProfileContext, formatFeedbackFlags } from '../context/profile-context';
import { RunContextInput, buildEventPrompt } from '../context/run-context';
import { stampVersion } from '../versions';
import { BuiltPrompt } from './types';

const RUN_TIME_EVENTS = new Set(['km_reached', 'pace_alert', 'start', 'finish']);

export interface LiveCoachBuildInput {
  profile: Partial<UserProfile> | null | undefined;
  runtimeContextJson: string;
  ctx: RunContextInput & { question?: string };
  ragContext: string;
  /** legacy fallback: CoachConfigService.livePrompt — overrides systemPrompt when set */
  legacyLivePrompt?: string;
}

export async function buildLiveCoachPrompt(args: LiveCoachBuildInput): Promise<BuiltPrompt> {
  const { config, source } = await getPromptConfig('live-coach');
  const tone = await resolvePersonaTone(args.profile?.coachPersonality);
  const isRunTime = RUN_TIME_EVENTS.has(args.ctx.event ?? '');
  const feedback = formatFeedbackFlags(args.profile);

  const eventPrompt = args.ctx.event === 'question' && args.ctx.question
    ? `O corredor perguntou: "${args.ctx.question}".`
    : buildEventPrompt(args.ctx);

  const values = {
    persona: { tone },
    profile: { context: formatProfileContext(args.profile) },
    runtime: { context: args.runtimeContextJson },
    feedback: {
      rules: [feedback.inclusionRules, feedback.exclusionRules].filter(Boolean).join(' '),
    },
    eventPrompt,
    rag: args.ragContext,
  };

  // Prioridade: novo store (firestore prompts) > default em código > legacy livePrompt (fallback final)
  let systemPrompt = renderTemplate(config.systemPrompt, values);
  let resolvedSource = source;

  if (source === 'default' && args.legacyLivePrompt && args.legacyLivePrompt.trim().length > 0) {
    // Só usa legacy quando admin ainda não setou nada no novo store
    systemPrompt = `${args.legacyLivePrompt}\n\nTOM (persona):\n${tone}`;
    resolvedSource = 'firestore';
  }

  if (!isRunTime) {
    systemPrompt += '\n\nFora da corrida: até 4 frases curtas, cabendo em até 30 segundos de áudio.';
  }

  return {
    systemPrompt,
    userPrompt: renderTemplate(config.userTemplate, values),
    maxTokens: isRunTime ? config.maxTokens : 1024,
    temperature: config.temperature,
    ragChunks: config.ragChunks,
    version: stampVersion('live-coach', resolvedSource),
    source: resolvedSource,
  };
}
