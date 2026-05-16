import { UserProfile } from '@modules/users/domain/user.entity';
import { Plan } from '@modules/plans/domain/plan.entity';
import { getPromptConfig } from '../config-store';
import { renderTemplate } from '../render';
import { resolvePersonaTone } from '../persona/resolver';
import { formatProfileContext } from '../context/profile-context';
import { stampVersion } from '../versions';
import { BuiltPrompt } from './types';

export interface PlanRevisionBuildInput {
  profile: Partial<UserProfile> | null | undefined;
  plan: Pick<Plan, 'goal' | 'level' | 'weeksCount' | 'weeks'>;
  revision: { type: string; subOption?: string; freeText?: string };
  ragContext: string;
}

export async function buildPlanRevisionPrompt(args: PlanRevisionBuildInput): Promise<BuiltPrompt> {
  const { config, source } = await getPromptConfig('plan-revision');
  const tone = await resolvePersonaTone(args.profile?.coachPersonality);

  const values = {
    persona: { tone },
    profile: { context: formatProfileContext(args.profile) },
    plan: {
      goal: args.plan.goal,
      level: args.plan.level,
      weeksCount: args.plan.weeksCount,
      weeksJson: JSON.stringify(args.plan.weeks),
    },
    revision: {
      type: args.revision.type,
      subOption: args.revision.subOption ?? '',
      freeText: args.revision.freeText ?? '',
    },
    rag: args.ragContext,
  };

  return {
    systemPrompt: renderTemplate(config.systemPrompt, values),
    userPrompt: renderTemplate(config.userTemplate, values),
    maxTokens: config.maxTokens,
    temperature: config.temperature,
    ragChunks: config.ragChunks,
    version: stampVersion('plan-revision', source),
    source,
  };
}
