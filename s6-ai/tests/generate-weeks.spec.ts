import { describe, it, expect, vi } from 'vitest';
import { GenerateWeeksUseCase, GenerateWeeksRequest } from '@modules/plan/generate-weeks.use-case';
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
    // eslint-disable-next-line require-yield
    stream: async function* (): AsyncGenerator<string> {
      throw new Error('not used');
    },
  };
}

function req(weeksCount = 2): GenerateWeeksRequest {
  return {
    userId: 'u1',
    profile: null,
    input: {
      goal: 'correr 5km',
      level: 'iniciante',
      frequency: 3,
      weeksCount,
      startDate: '2026-06-15',
    },
  };
}

const week = (n: number) => ({
  weekNumber: n,
  sessions: [{ dayOfWeek: 2, type: 'Easy Run', distanceKm: 4 + n, notes: '' }],
});

describe('GenerateWeeksUseCase', () => {
  it('caminho feliz: JSON válido com count correto', async () => {
    const llm = mockLlm([JSON.stringify([week(1), week(2)])]);
    const result = await new GenerateWeeksUseCase(llm).execute(req(2));
    expect(result.weeks).toHaveLength(2);
    expect(result.countMismatch).toBe(false);
    expect(result.weeks[1]?.weekNumber).toBe(2);
    expect(llm.generate).toHaveBeenCalledTimes(1);
  });

  it('output malformado → repair LLM resolve na 2ª chamada', async () => {
    const llm = mockLlm([
      'desculpa, não consegui gerar JSON {{{',
      JSON.stringify([week(1), week(2)]),
    ]);
    const result = await new GenerateWeeksUseCase(llm).execute(req(2));
    expect(result.weeks).toHaveLength(2);
    expect(llm.generate).toHaveBeenCalledTimes(2);
  });

  it('count menor → rebalance LLM completa', async () => {
    const llm = mockLlm([
      JSON.stringify([week(1)]),
      JSON.stringify([week(1), week(2)]),
    ]);
    const result = await new GenerateWeeksUseCase(llm).execute(req(2));
    expect(result.weeks).toHaveLength(2);
    expect(result.countMismatch).toBe(false);
    expect(llm.generate).toHaveBeenCalledTimes(2);
  });

  it('rebalance falha → countMismatch=true e devolve o que tem', async () => {
    const llm = mockLlm([
      JSON.stringify([week(1)]),
      JSON.stringify([week(1)]), // rebalance ainda devolve 1
    ]);
    const result = await new GenerateWeeksUseCase(llm).execute(req(3));
    expect(result.weeks).toHaveLength(1);
    expect(result.countMismatch).toBe(true);
  });

  it('count maior → trim sem chamada extra de LLM', async () => {
    const llm = mockLlm([JSON.stringify([week(1), week(2), week(3)])]);
    const result = await new GenerateWeeksUseCase(llm).execute(req(2));
    expect(result.weeks).toHaveLength(2);
    expect(llm.generate).toHaveBeenCalledTimes(1);
  });
});
