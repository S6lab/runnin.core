import { v4 as uuid } from 'uuid';
import { BiometricSample } from '../domain/biometric-sample.entity';
import { BiometricSampleRepository } from '../domain/biometric-sample.repository';

/**
 * Seed determinístico de 7 dias de dados biométricos pra um user de teste.
 *
 * Gera ~50 samples:
 * - 7x sleep_hours (1 por noite)
 * - 7x resting_bpm (1 por manhã)
 * - 7x max_bpm (1 por dia, picos durante corrida)
 * - 7x steps (1 contagem diária)
 * - 7x hrv (1 medição matinal)
 * - 7x calories_burned
 * - 1x weight
 * - 7x respiratory_rate
 *
 * Idempotente — usa doc id `{type}_{recordedAt}` no repo, sobrescreve sample
 * existente do mesmo type/timestamp.
 *
 * Valores são realistas pra um runner intermediário ~70kg.
 */
export class SeedTestUserUseCase {
  constructor(private readonly repo: BiometricSampleRepository) {}

  async execute(userId: string): Promise<{ seeded: number; user: string }> {
    const samples: BiometricSample[] = [];
    const now = new Date();
    const receivedAt = now.toISOString();

    for (let dayOffset = 6; dayOffset >= 0; dayOffset--) {
      const dayDate = new Date(now);
      dayDate.setDate(dayDate.getDate() - dayOffset);
      const morningKey = (() => {
        const d = new Date(dayDate);
        d.setUTCHours(7, 30, 0, 0);
        return d.toISOString();
      })();
      const nightKey = (() => {
        const d = new Date(dayDate);
        d.setUTCHours(23, 0, 0, 0);
        return d.toISOString();
      })();
      const eveningKey = (() => {
        const d = new Date(dayDate);
        d.setUTCHours(19, 0, 0, 0);
        return d.toISOString();
      })();

      // Sleep — varia entre 6.5 e 8.2 horas
      const sleepNoise = 0.8 * Math.sin(dayOffset * 1.7);
      samples.push(make({
        userId, type: 'sleep_hours', value: round(7.3 + sleepNoise, 1),
        unit: 'hours', source: 'seed', recordedAt: nightKey, receivedAt,
        context: {
          deepHours: round(1.5 + 0.3 * Math.sin(dayOffset), 2),
          remHours: round(1.8 + 0.4 * Math.cos(dayOffset), 2),
        },
      }));
      samples.push(make({
        userId, type: 'sleep_deep', value: round(1.5 + 0.3 * Math.sin(dayOffset), 2),
        unit: 'hours', source: 'seed', recordedAt: nightKey, receivedAt,
      }));

      // Resting BPM — varia 52-60
      samples.push(make({
        userId, type: 'resting_bpm', value: 56 + Math.round(2 * Math.sin(dayOffset * 0.9)),
        unit: 'bpm', source: 'seed', recordedAt: morningKey, receivedAt,
      }));

      // HRV — varia 38-58 ms
      samples.push(make({
        userId, type: 'hrv', value: 48 + Math.round(8 * Math.sin(dayOffset * 1.2)),
        unit: 'ms', source: 'seed', recordedAt: morningKey, receivedAt,
      }));

      // Steps — varia 7k-14k (mais nos dias de corrida)
      const isRunDay = dayOffset % 2 === 0;
      samples.push(make({
        userId, type: 'steps', value: isRunDay ? 12500 + Math.round(1500 * Math.cos(dayOffset)) : 7500 + Math.round(500 * Math.sin(dayOffset)),
        unit: 'count', source: 'seed', recordedAt: nightKey, receivedAt,
      }));

      // Max BPM — pico durante corrida
      samples.push(make({
        userId, type: 'max_bpm', value: isRunDay ? 168 + Math.round(8 * Math.sin(dayOffset)) : 110,
        unit: 'bpm', source: 'seed', recordedAt: eveningKey, receivedAt,
      }));

      // Respiratory rate — 14-18 rpm
      samples.push(make({
        userId, type: 'respiratory_rate', value: 15 + Math.round(2 * Math.sin(dayOffset * 0.7)),
        unit: 'rpm', source: 'seed', recordedAt: morningKey, receivedAt,
      }));

      // Calories — 1800-2400 kcal (dia normal) ou +500 em dias de corrida
      samples.push(make({
        userId, type: 'calories_burned', value: isRunDay ? 2400 : 1900,
        unit: 'kcal', source: 'seed', recordedAt: nightKey, receivedAt,
      }));
    }

    // Weight — só 1 medição (mais recente)
    samples.push(make({
      userId, type: 'weight', value: 71.5,
      unit: 'kg', source: 'seed',
      recordedAt: new Date(now.getTime() - 24 * 3600 * 1000).toISOString(),
      receivedAt,
    }));

    const result = await this.repo.saveBatch(samples);
    return { seeded: result.saved, user: userId };
  }
}

function make(s: Omit<BiometricSample, 'id'>): BiometricSample {
  return { id: uuid(), ...s };
}

function round(n: number, decimals: number): number {
  const factor = Math.pow(10, decimals);
  return Math.round(n * factor) / factor;
}
