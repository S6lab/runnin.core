import { UserProfile } from '@modules/users/domain/user.entity';
import { getPromptConfig } from '../config-store';
import { renderTemplate } from '../render';
import { resolvePersonaTone } from '../persona/resolver';
import { formatProfileContext } from '../context/profile-context';
import { stampVersion } from '../versions';
import { BuiltPrompt } from './types';

export interface PlanInitBuildInput {
  profile: Partial<UserProfile> | null | undefined;
  input: { goal: string; level: string; frequency: number; weeksCount: number };
  ragContext: string;
}

export async function buildPlanInitPrompt(args: PlanInitBuildInput): Promise<BuiltPrompt> {
  const { config, source } = await getPromptConfig('plan-init');
  const tone = await resolvePersonaTone(args.profile?.coachPersonality);

  const values = {
    persona: { tone },
    profile: { context: formatProfileContext(args.profile) },
    input: args.input,
    rag: args.ragContext,
  };

  return {
    systemPrompt: renderTemplate(config.systemPrompt, values),
    userPrompt: renderTemplate(config.userTemplate, values),
    maxTokens: config.maxTokens,
    temperature: config.temperature,
    ragChunks: config.ragChunks,
    version: stampVersion('plan-init', source),
    source,
  };
}
