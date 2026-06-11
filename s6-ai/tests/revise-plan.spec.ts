import { describe, it, expect, vi } from 'vitest';
import { RevisePlanUseCase, RevisePlanRequest } from '@modules/plan/revise-plan.use-case';
import { LLMProvider } from '@shared/infra/llm/llm.interface';

function mockLlm(responses: string[]): LLMProvider & { generate: ReturnType<typeof vi.fn> } {
  let i = 0;
  const generate = vi.fn(async () => {
    const r = responses[Math.min(i, responses.length - 1)];
    i++;
    return r as string;
  });
  return {
    generate,
    stream: async function* (): AsyncGenerator<string> {
      throw new Error('not used');
    },
  };
}

const VALID_RESPONSE = {
  coachExplanation: 'Reduzi a carga das próximas semanas pra respeitar o desconforto reportado.',
  newWeeks: [
    {
      weekNumber: 3,
      sessions: [{ dayOfWeek: 2, type: 'Easy Run', distanceKm: 4, notes: 'bem leve' }],
    },
  ],
};

function req(): RevisePlanRequest {
  return {
    userId: 'u1',
    profile: null,
    plan: {
      goal: 'correr 10km',
      level: 'iniciante',
      weeksCount: 8,
      weeks: [{ weekNumber: 3, sessions: [] }],
    },
    revision: { type: 'pain_or_discomfort', freeText: 'dor no joelho' },
    currentWeekNumber: 3,
  };
}

describe('RevisePlanUseCase', () => {
  it('caminho feliz', async () => {
    const llm = mockLlm([JSON.stringify(VALID_RESPONSE)]);
    const result = await new RevisePlanUseCase(llm).execute(req());
    expect(result.coachExplanation).toBe(VALID_RESPONSE.coachExplanation);
    expect(result.newWeeks).toHaveLength(1);
    expect(llm.generate).toHaveBeenCalledTimes(1);
  });

  it('JSON com fence + texto em volta', async () => {
    const llm = mockLlm(['Claro!\n```json\n' + JSON.stringify(VALID_RESPONSE) + '\n```']);
    const result = await new RevisePlanUseCase(llm).execute(req());
    expect(result.newWeeks).toHaveLength(1);
  });

  it('malformado → repair retry resolve', async () => {
    const llm = mockLlm(['{quebrado', JSON.stringify(VALID_RESPONSE)]);
    const result = await new RevisePlanUseCase(llm).execute(req());
    expect(result.coachExplanation).toContain('Reduzi');
    expect(llm.generate).toHaveBeenCalledTimes(2);
  });

  it('malformado nas duas tentativas → lança', async () => {
    const llm = mockLlm(['{quebrado', 'ainda {quebrado']);
    await expect(new RevisePlanUseCase(llm).execute(req())).rejects.toThrow();
  });
});
