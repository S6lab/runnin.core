import { z } from 'zod';
import { getRealtimeLLM } from '@shared/infra/llm/llm.factory';
import { formatRunningKnowledgeContext } from '@shared/knowledge/running/running-knowledge';

export const CoachContextSchema = z.object({
  runId: z.string(),
  event: z.enum(['km_reached', 'pace_alert', 'question', 'start', 'finish']),
  currentPaceMinKm: z.number(),
  targetPaceMinKm: z.number().optional(),
  distanceM: z.number(),
  elapsedS: z.number(),
  bpm: z.number().optional(),
  kmReached: z.number().optional(),
  question: z.string().optional(),
});

export type CoachContext = z.infer<typeof CoachContextSchema>;

const SYSTEM_PROMPT = `Você é o Coach.AI do runnin — um treinador de corrida experiente e direto.
Responda SEMPRE em português brasileiro, de forma concisa (máximo 2 frases curtas).
Use termos técnicos de corrida naturalmente: pace, BPM, cadência, zona aeróbica.
Seja motivador mas realista. Nunca use emojis. Tom: profissional e humano.`;

function buildPrompt(ctx: CoachContext): string {
  const pace = ctx.currentPaceMinKm.toFixed(2);
  const target = ctx.targetPaceMinKm?.toFixed(2) ?? 'livre';
  const dist = (ctx.distanceM / 1000).toFixed(2);
  const elapsed = `${Math.floor(ctx.elapsedS / 60)}min`;

  const base = `Corredor: ${dist}km rodados, pace atual ${pace}/km (alvo: ${target}/km), tempo ${elapsed}${ctx.bpm ? `, BPM ${ctx.bpm}` : ''}.`;

  const eventPrompt = (() => {
    switch (ctx.event) {
      case 'km_reached': return `${base} Acabou de completar o km ${ctx.kmReached}. Dê feedback rápido sobre o pace.`;
      case 'pace_alert': return `${base} Pace desviou do plano. Corrija o corredor de forma motivadora.`;
      case 'start': return `Corredor iniciando treino. Pace alvo: ${target}/km. Dê uma frase de largada motivadora.`;
      case 'finish': return `${base} Corrida finalizada! Dê parabéns e um insight rápido do desempenho.`;
      case 'question': return `${base} O corredor perguntou: "${ctx.question}". Responda brevemente.`;
      default: return base;
    }
  })();

  const knowledgeContext = formatRunningKnowledgeContext(
    `${ctx.event} corrida pace ${target} bpm ${ctx.bpm ?? ''} ${ctx.question ?? ''}`,
    2,
  );

  return `${eventPrompt}

Base de conhecimento:
${knowledgeContext}`;
}

export class CoachMessageUseCase {
  private llm = getRealtimeLLM();

  stream(ctx: CoachContext): AsyncGenerator<string> {
    const prompt = buildPrompt(ctx);
    return this.llm.stream(prompt, {
      systemPrompt: SYSTEM_PROMPT,
      maxTokens: 80,
      temperature: 0.75,
    });
  }
}
