import { z } from 'zod';
import { getAsyncLLM } from '@shared/infra/llm/llm.factory';
import { formatRunningKnowledgeContext } from '@shared/knowledge/running/running-knowledge';

export const CoachChatSchema = z.object({
  message: z.string().min(1, 'message is required'),
});

export type CoachChatInput = z.infer<typeof CoachChatSchema>;

const SYSTEM_PROMPT = `Você é o Coach.AI do runnin.
Responda sempre em português brasileiro com objetividade e clareza.
Dê orientação prática de treino, recuperação, ritmo e consistência.
Máximo 4 frases curtas. Sem emojis.`;

export class CoachChatUseCase {
  private llm = getAsyncLLM();

  async execute(input: CoachChatInput): Promise<string> {
    const knowledgeContext = formatRunningKnowledgeContext(input.message, 3);
    const prompt = `Mensagem do corredor: "${input.message}".
Responda como coach de corrida com próximos passos claros e aplicáveis agora.

Base de conhecimento:
${knowledgeContext}`;

    return this.llm.generate(prompt, {
      systemPrompt: SYSTEM_PROMPT,
      maxTokens: 220,
      temperature: 0.7,
    });
  }
}
