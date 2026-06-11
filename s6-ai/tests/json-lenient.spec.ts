import { describe, it, expect } from 'vitest';
import {
  parseJsonLenient,
  extractWeeksCandidate,
  coerceWeeksLenient,
} from '@modules/plan/json-lenient';
import { RawPlanWeeksSchema } from '@modules/plan/raw-weeks.schema';

const VALID_WEEK = {
  weekNumber: 1,
  sessions: [{ dayOfWeek: 2, type: 'Easy Run', distanceKm: 5, notes: 'leve' }],
};

describe('parseJsonLenient', () => {
  it('parseia JSON limpo', () => {
    expect(parseJsonLenient(JSON.stringify([VALID_WEEK]))).toEqual([VALID_WEEK]);
  });

  it('parseia JSON dentro de fence markdown', () => {
    const raw = 'Aqui está o plano:\n```json\n' + JSON.stringify([VALID_WEEK]) + '\n```\nBom treino!';
    expect(parseJsonLenient(raw)).toEqual([VALID_WEEK]);
  });

  it('repara trailing commas', () => {
    const raw = '[{"weekNumber": 1, "sessions": [{"dayOfWeek": 2, "type": "Easy Run", "distanceKm": 5, "notes": "",},],}]';
    const parsed = parseJsonLenient(raw) as Array<Record<string, unknown>>;
    expect(parsed[0]?.weekNumber).toBe(1);
  });

  it('fecha JSON truncado (brackets desbalanceados)', () => {
    const raw = '[{"weekNumber": 1, "sessions": [{"dayOfWeek": 2, "type": "Easy Run", "distanceKm": 5, "notes": "corte';
    const parsed = parseJsonLenient(raw) as Array<Record<string, unknown>>;
    expect(parsed[0]?.weekNumber).toBe(1);
  });

  it('lança quando nada é parseável', () => {
    expect(() => parseJsonLenient('isso não é json de jeito nenhum')).toThrow();
  });
});

describe('extractWeeksCandidate', () => {
  it('desembrulha {weeks: [...]}', () => {
    expect(extractWeeksCandidate({ weeks: [VALID_WEEK] })).toEqual([VALID_WEEK]);
  });

  it('embrulha week solta em array', () => {
    expect(extractWeeksCandidate(VALID_WEEK)).toEqual([VALID_WEEK]);
  });

  it('passthrough de array', () => {
    expect(extractWeeksCandidate([VALID_WEEK])).toEqual([VALID_WEEK]);
  });
});

describe('coerceWeeksLenient + RawPlanWeeksSchema', () => {
  it('deriva weekNumber faltante do index e dropa session inválida', () => {
    const input = [
      {
        sessions: [
          { dayOfWeek: 2, type: 'Easy Run', distanceKm: 5, notes: '' },
          { dayOfWeek: undefined, type: 'Tiros', distanceKm: 4 }, // dropada
        ],
      },
      { weekNumber: 2, sessions: [{ dayOfWeek: 4, type: 'Long Run', distanceKm: 8, notes: '' }] },
    ];
    const coerced = coerceWeeksLenient(input);
    const parsed = RawPlanWeeksSchema.parse(coerced);
    expect(parsed).toHaveLength(2);
    expect(parsed[0]?.weekNumber).toBe(1);
    expect(parsed[0]?.sessions).toHaveLength(1);
  });

  it('limpa opcionais malformados em vez de rejeitar', () => {
    const input = [
      {
        weekNumber: 1,
        sessions: [
          {
            dayOfWeek: 2,
            type: 'Easy Run',
            distanceKm: 5,
            notes: '',
            durationMin: -3,
            targetPace: '',
            hydrationLiters: 0,
          },
        ],
      },
    ];
    const parsed = RawPlanWeeksSchema.parse(coerceWeeksLenient(input));
    const session = parsed[0]?.sessions[0];
    expect(session?.durationMin).toBeUndefined();
    expect(session?.targetPace).toBeUndefined();
    expect(session?.hydrationLiters).toBeUndefined();
  });

  it('sessions ausente vira []', () => {
    const parsed = RawPlanWeeksSchema.parse(coerceWeeksLenient([{ weekNumber: 1 }]));
    expect(parsed[0]?.sessions).toEqual([]);
  });
});
