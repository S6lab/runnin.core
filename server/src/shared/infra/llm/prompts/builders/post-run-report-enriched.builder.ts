import { UserProfile } from '@modules/users/domain/user.entity';
import { getPromptConfig } from '../config-store';
import { renderTemplate } from '../render';
import { resolvePersonaTone } from '../persona/resolver';
import { formatProfileContext } from '../context/profile-context';
import { stampVersion } from '../versions';
import { BuiltPrompt } from './types';

export interface PostRunReportEnrichedBuildInput {
  profile: Partial<UserProfile> | null | undefined;
  run: { summary: string };
  planContext: string;
  /** Resultado da revisão automática do plano após esta corrida. Vazio
   *  string quando não houve revisão (sem plano OU adapter desligado). */
  planAdaptResult: string;
  recentRunsContext: string;
  ragContext: string;
}

/**
 * Builder da fase B (enriched) do relatório pós-corrida. Output esperado:
 * JSON `{ runAnalysis, planEvolution, nextSessions, recommendations }`.
 * Parse defensivo no use-case (LLM pode entregar com fence, com texto
 * antes/depois, etc).
 */
export async function buildPostRunReportEnrichedPrompt(
  args: PostRunReportEnrichedBuildInput,
): Promise<BuiltPrompt> {
  const { config, source } = await getPromptConfig('post-run-report-enriched');
  const tone = await resolvePersonaTone(args.profile?.coachPersonality);

  const values = {
    persona: { tone },
    profile: { context: formatProfileContext(args.profile) },
    run: { summary: args.run.summary },
    plan: {
      context: args.planContext,
      adaptResult: args.planAdaptResult || '(sem revisão automática nesta corrida)',
    },
    recentRuns: args.recentRunsContext,
    rag: args.ragContext,
  };

  return {
    systemPrompt: renderTemplate(config.systemPrompt, values),
    userPrompt: renderTemplate(config.userTemplate, values),
    maxTokens: config.maxTokens,
    temperature: config.temperature,
    ragChunks: config.ragChunks,
    version: stampVersion('post-run-report-enriched', source),
    source,
  };
}
