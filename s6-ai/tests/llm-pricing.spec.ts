import { describe, it, expect } from 'vitest';
import { computeCostUsd, listKnownModels } from '@shared/infra/llm/llm-pricing';

describe('computeCostUsd', () => {
  it('calcula custo input+output por 1M tokens', () => {
    // gemini-3.5-flash: 0.075 in / 0.30 out por 1M
    const cost = computeCostUsd('gemini-3.5-flash', 1_000_000, 1_000_000);
    expect(cost).toBeCloseTo(0.375, 6);
  });

  it('modelo desconhecido retorna 0', () => {
    expect(computeCostUsd('modelo-inexistente', 1000, 1000)).toBe(0);
  });

  it('tabela cobre os modelos principais', () => {
    const models = listKnownModels();
    expect(models).toContain('gemini-3.5-flash');
    expect(models).toContain('gemini-2.5-flash-native-audio');
  });
});
