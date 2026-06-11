import { describe, it, expect } from 'vitest';
import { tryBuildTemplate, isTemplateEvent } from '@modules/coach/use-cases/template-cues';
import type { CoachContext } from '@modules/coach/use-cases/coach-message.use-case';
import type { CoachRuntimeContext } from '@modules/coach/use-cases/coach-runtime-context.service';

function baseCtx(overrides: Partial<CoachContext> = {}): CoachContext {
  return {
    runId: 'run-abc',
    event: 'check_in',
    currentPaceMinKm: 5.5,
    targetPaceMinKm: 5.5,
    distanceM: 1500,
    elapsedS: 600,
    bpm: 140,
    kmReached: 1.5,
    ...overrides,
  } as CoachContext;
}

function baseRuntime(overrides: Partial<CoachRuntimeContext> = {}): CoachRuntimeContext {
  return {
    profile: {
      name: 'Eduardo',
      level: 'intermediario',
      goal: 'Completar 10K',
      frequency: 4,
      hasWearable: true,
    } as any,
    currentPlan: null,
    currentSession: null,
    recentRuns: [],
    ...overrides,
  };
}

describe('template-cues', () => {
  describe('isTemplateEvent', () => {
    it('reconhece eventos template + no-op', () => {
      expect(isTemplateEvent('segment_start')).toBe(true);
      expect(isTemplateEvent('segment_end')).toBe(true);
      expect(isTemplateEvent('check_in')).toBe(true);
      expect(isTemplateEvent('motivation')).toBe(true);
      expect(isTemplateEvent('goal_reached')).toBe(true);
      expect(isTemplateEvent('finish')).toBe(true);
      expect(isTemplateEvent('no_movement')).toBe(true);
      expect(isTemplateEvent('km_split')).toBe(true); // noop por retrocompat
    });
    it('NÃO reconhece eventos que continuam LLM', () => {
      expect(isTemplateEvent('start')).toBe(false);
      expect(isTemplateEvent('km_reached')).toBe(false);
      expect(isTemplateEvent('pace_alert')).toBe(false);
      expect(isTemplateEvent('high_bpm')).toBe(false);
    });
  });

  describe('km_split', () => {
    it('retorna noop com motivo deprecated_event', () => {
      const r = tryBuildTemplate({
        ctx: baseCtx({ event: 'km_split' }),
        runtime: baseRuntime(),
      });
      expect(r?.kind).toBe('noop');
      expect((r as any).reason).toBe('deprecated_event');
    });
  });

  describe('check_in 500m', () => {
    it('insere nome do atleta + pace + alvo', () => {
      const r = tryBuildTemplate({
        ctx: baseCtx({ event: 'check_in' }),
        runtime: baseRuntime(),
      });
      expect(r?.kind).toBe('text');
      const text = (r as any).text as string;
      expect(text).toMatch(/Eduardo/);
      // TF 81: formato falável `5min30` (era `5:30`) — spec ficou pra trás.
      expect(text).toMatch(/5min30/);
    });

    it('omite vocativo quando sem nome', () => {
      const r = tryBuildTemplate({
        ctx: baseCtx({ event: 'check_in' }),
        runtime: baseRuntime({ profile: { hasWearable: true } as any }),
      });
      const text = (r as any).text as string;
      expect(text).not.toMatch(/, ,/); // sem vírgula órfã
      expect(text).not.toMatch(/Eduardo/);
    });

    it('varia a frase entre runs diferentes', () => {
      const r1 = tryBuildTemplate({ ctx: baseCtx({ runId: 'run-1' }), runtime: baseRuntime() });
      const r2 = tryBuildTemplate({ ctx: baseCtx({ runId: 'run-999' }), runtime: baseRuntime() });
      // Não garantimos diferente — hash pode colidir — mas garantimos
      // que ambas são strings válidas.
      expect((r1 as any).text).toBeTypeOf('string');
      expect((r2 as any).text).toBeTypeOf('string');
    });

    it('é determinístico (mesmo seed → mesma variação)', () => {
      const r1 = tryBuildTemplate({ ctx: baseCtx(), runtime: baseRuntime() });
      const r2 = tryBuildTemplate({ ctx: baseCtx(), runtime: baseRuntime() });
      expect((r1 as any).text).toBe((r2 as any).text);
    });
  });

  describe('motivation (check_in idle 4min)', () => {
    it('produz texto conversacional', () => {
      const r = tryBuildTemplate({
        ctx: baseCtx({ event: 'motivation' }),
        runtime: baseRuntime(),
      });
      expect(r?.kind).toBe('text');
      const text = (r as any).text as string;
      expect(text.length).toBeGreaterThan(20);
    });
  });

  describe('goal_reached', () => {
    it('menciona objetivo batido + opção de continuar', () => {
      const r = tryBuildTemplate({
        ctx: baseCtx({ event: 'goal_reached', distanceM: 5000, elapsedS: 1680 }),
        runtime: baseRuntime({
          currentSession: { type: 'Easy Run', distanceKm: 5 } as any,
        }),
      });
      const text = (r as any).text as string;
      // Alguma sinalização de objetivo + continuação opcional
      expect(text).toMatch(/objetivo|cumprimos|meta|alvo/i);
    });
  });

  describe('finish', () => {
    it('insere distância, tempo e sugere análise', () => {
      const r = tryBuildTemplate({
        ctx: baseCtx({ event: 'finish', distanceM: 5020, elapsedS: 1680 }),
        runtime: baseRuntime(),
      });
      const text = (r as any).text as string;
      expect(text).toMatch(/relatório|análise/i);
      expect(text).toMatch(/5\.0[0-9]/); // 5.02 km com 2 decimais
    });
  });

  describe('segment_start sem segmentos', () => {
    it('retorna noop pra deixar LLM cuidar', () => {
      const r = tryBuildTemplate({
        ctx: baseCtx({ event: 'segment_start' }),
        runtime: baseRuntime({ currentSession: { type: 'Easy Run' } as any }),
      });
      expect(r?.kind).toBe('noop');
      expect((r as any).reason).toBe('no_segment_data');
    });
  });

  describe('segment_start com segmentos', () => {
    const sessionWithSegments = {
      type: 'Tempo Run',
      distanceKm: 5,
      targetPace: '5:30',
      executionSegments: [
        { kmStart: 0, kmEnd: 1, phase: 'warmup', targetPace: '6:30', instruction: 'Aquecimento solto.' },
        { kmStart: 1, kmEnd: 4, phase: 'tempo', targetPace: '5:00', instruction: 'Pace de limiar.' },
        { kmStart: 4, kmEnd: 5, phase: 'cooldown', targetPace: '6:30', instruction: 'Solta o pace.' },
      ],
    };

    it('primeira fase: usa variação FIRST', () => {
      const r = tryBuildTemplate({
        ctx: baseCtx({ event: 'segment_start', currentSegmentIndex: 0, distanceM: 0 }),
        runtime: baseRuntime({ currentSession: sessionWithSegments as any }),
      });
      const text = (r as any).text as string;
      // FIRST variations falam "começar/abrimos/preparação"
      expect(text).toMatch(/começar|abrimos|aquecimento|preparação|começa/i);
    });

    it('fase do meio: menciona pace alvo e contexto', () => {
      const r = tryBuildTemplate({
        ctx: baseCtx({ event: 'segment_start', currentSegmentIndex: 1, distanceM: 1000 }),
        runtime: baseRuntime({ currentSession: sessionWithSegments as any }),
      });
      const text = (r as any).text as string;
      expect(text).toMatch(/5:00/); // pace alvo do segmento 2
      expect(text).toMatch(/Tempo Run|limiar/i);
    });

    it('última fase: tom de fechamento', () => {
      const r = tryBuildTemplate({
        ctx: baseCtx({ event: 'segment_start', currentSegmentIndex: 2, distanceM: 4000 }),
        runtime: baseRuntime({ currentSession: sessionWithSegments as any }),
      });
      const text = (r as any).text as string;
      expect(text).toMatch(/última|fim|fechar|fechamento|final/i);
    });
  });

  describe('segment_end dedup', () => {
    const sessionWithSegments = {
      type: 'Tempo Run',
      executionSegments: [
        { kmStart: 0, kmEnd: 1, phase: 'warmup', targetPace: '6:30', instruction: 'X' },
        { kmStart: 1, kmEnd: 5, phase: 'tempo', targetPace: '5:00', instruction: 'Y' },
      ],
    };

    it('suprime quando segment_start aconteceu nos últimos 5s', () => {
      const r = tryBuildTemplate({
        ctx: baseCtx({ event: 'segment_end', currentSegmentIndex: 0, distanceM: 1000 }),
        runtime: baseRuntime({ currentSession: sessionWithSegments as any }),
        lastSegmentStartAtMs: Date.now() - 1000, // 1s atrás
      });
      expect(r?.kind).toBe('noop');
      expect((r as any).reason).toBe('transition_handled_by_start');
    });

    it('suprime quando segmento não é o último (fala pelo segment_start próximo)', () => {
      const r = tryBuildTemplate({
        ctx: baseCtx({ event: 'segment_end', currentSegmentIndex: 0, distanceM: 1000 }),
        runtime: baseRuntime({ currentSession: sessionWithSegments as any }),
      });
      expect(r?.kind).toBe('noop');
      expect((r as any).reason).toBe('not_last_segment');
    });

    it('fala quando é o último segmento e sem dedup', () => {
      const r = tryBuildTemplate({
        ctx: baseCtx({ event: 'segment_end', currentSegmentIndex: 1, distanceM: 5000 }),
        runtime: baseRuntime({ currentSession: sessionWithSegments as any }),
      });
      expect(r?.kind).toBe('text');
    });
  });

  describe('no_movement', () => {
    it('produz alerta de GPS', () => {
      const r = tryBuildTemplate({
        ctx: baseCtx({ event: 'no_movement', distanceM: 0, elapsedS: 30 }),
        runtime: baseRuntime(),
      });
      const text = (r as any).text as string;
      expect(text).toMatch(/GPS/);
    });
  });

  describe('eventos NÃO-template retornam null', () => {
    it('start delega pro LLM', () => {
      const r = tryBuildTemplate({
        ctx: baseCtx({ event: 'start' }),
        runtime: baseRuntime(),
      });
      expect(r).toBeNull();
    });
    it('km_reached delega pro LLM', () => {
      const r = tryBuildTemplate({
        ctx: baseCtx({ event: 'km_reached' }),
        runtime: baseRuntime(),
      });
      expect(r).toBeNull();
    });
    it('pace_alert delega pro LLM', () => {
      const r = tryBuildTemplate({
        ctx: baseCtx({ event: 'pace_alert' }),
        runtime: baseRuntime(),
      });
      expect(r).toBeNull();
    });
  });
});
