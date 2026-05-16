import { UserProfile } from '@modules/users/domain/user.entity';
import { getPromptConfig } from '../config-store';
import { renderTemplate } from '../render';
import { resolvePersonaTone } from '../persona/resolver';
import { formatProfileContext } from '../context/profile-context';
import { stampVersion } from '../versions';
import { BuiltPrompt } from './types';

export interface PostRunReportBuildInput {
  profile: Partial<UserProfile> | null | undefined;
  run: { summary: string };
  planContext: string;
  recentRunsContext: string;
  ragContext: string;
}

export async function buildPostRunReportPrompt(args: PostRunReportBuildInput): Promise<BuiltPrompt> {
  const { config, source } = await getPromptConfig('post-run-report');
  const tone = await resolvePersonaTone(args.profile?.coachPersonality);

  const values = {
    persona: { tone },
    profile: { context: formatProfileContext(args.profile) },
    run: { summary: args.run.summary },
    plan: { context: args.planContext },
    recentRuns: args.recentRunsContext,
    rag: args.ragContext,
  };

  return {
    systemPrompt: renderTemplate(config.systemPrompt, values),
    userPrompt: renderTemplate(config.userTemplate, values),
    maxTokens: config.maxTokens,
    temperature: config.temperature,
    ragChunks: config.ragChunks,
    version: stampVersion('post-run-report', source),
    source,
  };
}
