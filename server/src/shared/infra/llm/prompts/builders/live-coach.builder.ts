import { UserProfile } from '@modules/users/domain/user.entity';
import { getKnobs, getPromptConfig } from '../config-store';
import { renderTemplate } from '../render';
import { resolvePersonaTone } from '../persona/resolver';
import { formatProfileContext, formatFeedbackFlags } from '../context/profile-context';
import { RunContextInput, buildEventPrompt } from '../context/run-context';
import { stampVersion } from '../versions';
import { BuiltPrompt } from './types';

const RUN_TIME_EVENTS = new Set([
  'km_reached',
  'km_split',
  'pace_alert',
  'motivation',
  'start',
  'finish',
  'segment_start',
  'segment_pace_off',
  'segment_end',
]);

export interface LiveCoachBuildInput {
  profile: Partial<UserProfile> | null | undefined;
  runtimeContextJson: string;
  ctx: RunContextInput & { question?: string };
  ragContext: string;
}

export async function buildLiveCoachPrompt(args: LiveCoachBuildInput): Promise<BuiltPrompt> {
  const [{ config, source }, tone, knobs] = await Promise.all([
    getPromptConfig('live-coach'),
    resolvePersonaTone(args.profile?.coachPersonality),
    getKnobs(),
  ]);
  const isRunTime = RUN_TIME_EVENTS.has(args.ctx.event ?? '');
  const feedback = formatFeedbackFlags(args.profile, {
    respectToggles: knobs.respectFeedbackToggles,
  });

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

  // Fonte única: config-store (firestore prompts > default em código). Sem
  // override legado — o prompt da voz é editado em /admin/prompts (live-coach).
  let systemPrompt = renderTemplate(config.systemPrompt, values);
  const resolvedSource = source;

  if (!isRunTime) {
    systemPrompt += '\n\nFora da corrida: até 4 frases curtas, cabendo em até 30 segundos de áudio.';
  }

  return {
    systemPrompt,
    userPrompt: renderTemplate(config.userTemplate, values),
    // TF 77 F5: força minimum 200 tokens mesmo se Firestore admin override
    // baixou pra 40-80. Eduardo viu finish:MAX_TOKENS recorrente em prod
    // (cues truncadas mid-frase). Math.max(config, 200) protege contra
    // misconfig sem mexer no admin panel.
    maxTokens: isRunTime ? Math.max(config.maxTokens, 200) : 1024,
    temperature: config.temperature,
    ragChunks: config.ragChunks,
    version: stampVersion('live-coach', resolvedSource),
    source: resolvedSource,
  };
}
