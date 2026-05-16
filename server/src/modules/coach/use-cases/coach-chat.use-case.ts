import { z } from 'zod';
import { getAsyncLLM } from '@shared/infra/llm/llm.factory';
import { formatRunningKnowledgeContext } from '@shared/knowledge/running/running-knowledge';
import { buildCoachChatPrompt } from '@shared/infra/llm/prompts';
import { CoachRuntimeContextService } from './coach-runtime-context.service';
import { logger } from '@shared/logger/logger';

export const CoachChatSchema = z.object({
  message: z.string().min(1, 'message is required'),
});

export type CoachChatInput = z.infer<typeof CoachChatSchema>;

export class CoachChatUseCase {
  private llm = getAsyncLLM();
  private runtime = new CoachRuntimeContextService();

  async execute(input: CoachChatInput, userId: string): Promise<string> {
    const runtime = await this.runtime.getContext(userId);
    const knowledgeContext = await formatRunningKnowledgeContext(input.message, 3);

    const planContext = runtime.currentPlan
      ? `Plano atual: ${runtime.currentPlan.goal} (${runtime.currentPlan.level}, ${runtime.currentPlan.weeksCount} semanas, status ${runtime.currentPlan.status})`
      : 'Sem plano ativo.';

    const recentRunsContext = runtime.recentRuns.length > 0
      ? runtime.recentRuns
          .slice(0, 3)
          .map(r => `${r.type} ${r.distanceKm}km em ${r.durationMin}min${r.avgPace ? ` (pace ${r.avgPace})` : ''}`)
          .join('; ')
      : 'Sem corridas recentes.';

    const built = await buildCoachChatPrompt({
      profile: runtime.profile,
      question: input.message,
      planContext,
      recentRunsContext,
      ragContext: knowledgeContext,
    });

    logger.info('coach.chat.prompt', { version: built.version, source: built.source });

    return this.llm.generate(built.userPrompt, {
      systemPrompt: built.systemPrompt,
      maxTokens: built.maxTokens,
      temperature: built.temperature,
    });
  }
}
