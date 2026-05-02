import { z } from 'zod';
import { getAsyncLLM } from '@shared/infra/llm/llm.factory';
import { formatRunningKnowledgeContext } from '@shared/knowledge/running/running-knowledge';

export const CoachChatSchema = z.object({
  message: z.string().min(1, 'message is required'),
});

export type CoachChatInput = z.infer<typeof CoachChatSchema>;

const SYSTEM_PROMPT = `Você é o Coach.AI do runnin: um personal trainer de corrida experiente, presente e direto.
Responda sempre em português brasileiro, falando diretamente com o corredor.
Use tom humano de treino: motivador, firme, pratico e cuidadoso com risco de lesao.
Dê orientação aplicada para treino, recuperação, ritmo e consistência.
Prefira frases como um treinador falaria no treino: "vamos ajustar", "segura o pace", "hoje o foco e recuperar".
Máximo 4 frases curtas. Sem emojis.`;

export class CoachChatUseCase {
  private llm = getAsyncLLM();

  async execute(input: CoachChatInput): Promise<string> {
    const knowledgeContext = await formatRunningKnowledgeContext(input.message, 3);
    const prompt = `Mensagem do corredor: "${input.message}".
Responda como personal trainer de corrida com proximos passos claros e aplicaveis agora.

Base de conhecimento:
${knowledgeContext}`;

    return this.llm.generate(prompt, {
      systemPrompt: SYSTEM_PROMPT,
      maxTokens: 220,
      temperature: 0.7,
    });
  }
}
