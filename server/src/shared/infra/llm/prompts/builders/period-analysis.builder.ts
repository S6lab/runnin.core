import { UserProfile } from '@modules/users/domain/user.entity';
import { getPromptConfig } from '../config-store';
import { renderTemplate } from '../render';
import { resolvePersonaTone } from '../persona/resolver';
import { formatProfileContext } from '../context/profile-context';
import { stampVersion } from '../versions';
import { BuiltPrompt } from './types';

export interface PeriodAnalysisBuildInput {
  profile: Partial<UserProfile> | null | undefined;
  period: { range: string; metrics: string; runs: string };
  ragContext: string;
}

export async function buildPeriodAnalysisPrompt(args: PeriodAnalysisBuildInput): Promise<BuiltPrompt> {
  const { config, source } = await getPromptConfig('period-analysis');
  const tone = await resolvePersonaTone(args.profile?.coachPersonality);

  const values = {
    persona: { tone },
    profile: { context: formatProfileContext(args.profile) },
    period: args.period,
    rag: args.ragContext,
  };

  return {
    systemPrompt: renderTemplate(config.systemPrompt, values),
    userPrompt: renderTemplate(config.userTemplate, values),
    maxTokens: config.maxTokens,
    temperature: config.temperature,
    ragChunks: config.ragChunks,
    version: stampVersion('period-analysis', source),
    source,
  };
}
