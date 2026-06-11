import { UserProfile } from '@modules/users/domain/user.entity';
import { getPromptConfig } from '../config-store';
import { renderTemplate } from '../render';
import { formatProfileContext } from '../context/profile-context';
import { stampVersion } from '../versions';
import { BuiltPrompt } from './types';

export interface ExamAnalysisBuildInput {
  profile: Partial<UserProfile> | null | undefined;
  schema: string;
}

export async function buildExamAnalysisPrompt(args: ExamAnalysisBuildInput): Promise<BuiltPrompt> {
  const { config, source } = await getPromptConfig('exam-analysis');

  const values = {
    profile: { context: formatProfileContext(args.profile) },
    schema: args.schema,
  };

  return {
    systemPrompt: renderTemplate(config.systemPrompt, values),
    userPrompt: renderTemplate(config.userTemplate, values),
    maxTokens: config.maxTokens,
    temperature: config.temperature,
    ragChunks: config.ragChunks,
    version: stampVersion('exam-analysis', source),
    source,
  };
}
