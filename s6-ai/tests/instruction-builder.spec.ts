import { describe, it, expect } from 'vitest';
import { buildLiveInstruction, INSTRUCTION_TOKEN_CAP } from '@modules/live/instruction-builder';
import { LiveSessionContextSchema } from '@modules/live/live-session.types';
import { approxTokens } from '@modules/live/cue-session';

function ctx(overrides: Record<string, unknown> = {}) {
  return LiveSessionContextSchema.parse({
    userId: 'u1',
    profileSnippet: 'nome Edu, nível iniciante, objetivo "5km", 3x/semana',
    sessionBriefing: 'SESSÃO DE HOJE: Tiros · 6km · pace alvo 5:30',
    ...overrides,
  });
}

describe('buildLiveInstruction — cap G3', () => {
  it('contexto normal: sem truncamento, inclui weather e segments', async () => {
    const built = await buildLiveInstruction(ctx({
      weather: { temperatureC: 24, humidityPercent: 60 },
      segments: [
        { kmStart: 0, kmEnd: 1, phase: 'aquecimento', targetPace: '6:30', instruction: 'trote leve' },
        { kmStart: 1, kmEnd: 5, phase: 'tiros', targetPace: '5:00', instruction: '400m forte / 200m leve' },
      ],
    }));
    expect(built.truncated).toEqual([]);
    expect(built.text).toContain('CLIMA NO MOMENTO');
    expect(built.text).toContain('ROTEIRO (fases):');
    expect(built.tokensApprox).toBeLessThanOrEqual(INSTRUCTION_TOKEN_CAP);
  });

  it('overflow: dropa weather primeiro, depois notes, e respeita o cap', async () => {
    const hugeSegments = Array.from({ length: 30 }, (_, i) => ({
      kmStart: i,
      kmEnd: i + 1,
      phase: `fase-${i}`,
      targetPace: '5:30',
      instruction: 'instrução bem detalhada repetida muitas vezes pra estourar o orçamento de tokens da instruction do live '.repeat(3),
    }));
    const built = await buildLiveInstruction(ctx({
      weather: { temperatureC: 24, humidityPercent: 60, windKmh: 10 },
      sessionNotes: 'foco em cadência alta e respiração nasal '.repeat(20),
      segments: hugeSegments,
    }));
    expect(built.truncated).toContain('weather');
    expect(built.text).not.toContain('CLIMA NO MOMENTO');
    expect(approxTokens(built.text)).toBeLessThanOrEqual(INSTRUCTION_TOKEN_CAP);
  });
});
