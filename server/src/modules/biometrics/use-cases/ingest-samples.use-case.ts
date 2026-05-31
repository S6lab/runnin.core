import { v4 as uuid } from 'uuid';
import { z } from 'zod';
import {
  BiometricSample,
  BiometricSampleType,
  BiometricSource,
} from '../domain/biometric-sample.entity';
import { BiometricSampleRepository } from '../domain/biometric-sample.repository';

const SampleInputSchema = z.object({
  type: z.enum([
    'bpm',
    'resting_bpm',
    'max_bpm',
    'hrv',
    'sleep_hours',
    'sleep_deep',
    'steps',
    'spo2',
    'weight',
    'calories_burned',
    'vo2max',
    'respiratory_rate',
  ]),
  value: z.number().finite(),
  unit: z.string().min(1),
  source: z.enum([
    'apple_health',
    'health_connect',
    'garmin',
    'polar',
    'fitbit',
    'whoop',
    'manual',
    'terra',
    'seed',
  ]),
  recordedAt: z.string(),
  context: z.record(z.string(), z.unknown()).optional(),
});

export const IngestSamplesSchema = z.object({
  samples: z.array(SampleInputSchema).min(1).max(500),
});

export type IngestSamplesInput = z.infer<typeof IngestSamplesSchema>;

export class IngestSamplesUseCase {
  constructor(private readonly repo: BiometricSampleRepository) {}

  async execute(
    userId: string,
    input: IngestSamplesInput,
  ): Promise<{ received: number; saved: number }> {
    const now = new Date().toISOString();
    const samples: BiometricSample[] = input.samples.map((s) => ({
      id: uuid(),
      userId,
      type: s.type as BiometricSampleType,
      value: s.value,
      unit: s.unit,
      source: s.source as BiometricSource,
      recordedAt: s.recordedAt,
      receivedAt: now,
      context: s.context,
    }));
    const result = await this.repo.saveBatch(samples);
    return { received: samples.length, saved: result.saved };
  }
}
