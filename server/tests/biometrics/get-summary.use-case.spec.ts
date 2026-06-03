import { describe, it, expect, beforeEach } from 'vitest';
import { GetSummaryUseCase } from '@modules/biometrics/use-cases/get-summary.use-case';
import {
  BiometricSample,
  BiometricSampleType,
} from '@modules/biometrics/domain/biometric-sample.entity';
import { BiometricSampleRepository } from '@modules/biometrics/domain/biometric-sample.repository';

class StubRepo implements BiometricSampleRepository {
  samples: BiometricSample[] = [];
  async saveBatch(_s: BiometricSample[]) {
    return { saved: 0, duplicates: 0 };
  }
  async findLatestByType(_userId: string, _type: BiometricSampleType) {
    return null;
  }
  async findByDateRange(
    _userId: string,
    _type: BiometricSampleType | undefined,
    _from: Date,
    _to: Date,
  ) {
    return this.samples;
  }
  async deleteByUser(_userId: string) {
    return 0;
  }
}

const mkSample = (
  type: BiometricSampleType,
  value: number,
  recordedAt: string,
): BiometricSample => ({
  id: `s-${type}-${recordedAt}`,
  userId: 'uid',
  type,
  value,
  unit: 'bpm',
  source: 'apple_health',
  recordedAt,
  receivedAt: recordedAt,
});

describe('GetSummaryUseCase', () => {
  let repo: StubRepo;
  let useCase: GetSummaryUseCase;

  beforeEach(() => {
    repo = new StubRepo();
    useCase = new GetSummaryUseCase(repo);
  });

  it('devolve nulls quando não há amostras', async () => {
    const summary = await useCase.execute('uid', 7);
    expect(summary.sampleCount).toBe(0);
    expect(summary.avgRestingBpm).toBe(null);
    expect(summary.maxBpm).toBe(null);
    expect(summary.totalSteps).toBe(null);
  });

  it('calcula média de resting_bpm', async () => {
    repo.samples = [
      mkSample('resting_bpm', 50, '2026-06-01T00:00:00.000Z'),
      mkSample('resting_bpm', 52, '2026-06-02T00:00:00.000Z'),
      mkSample('resting_bpm', 54, '2026-06-03T00:00:00.000Z'),
    ];
    const summary = await useCase.execute('uid', 7);
    expect(summary.avgRestingBpm).toBeCloseTo(52, 0);
  });

  it('calcula max_bpm como pico do período', async () => {
    repo.samples = [
      mkSample('max_bpm', 180, '2026-06-01T00:00:00.000Z'),
      mkSample('max_bpm', 195, '2026-06-02T00:00:00.000Z'),
      mkSample('max_bpm', 185, '2026-06-03T00:00:00.000Z'),
    ];
    const summary = await useCase.execute('uid', 7);
    expect(summary.maxBpm).toBe(195);
  });

  it('soma steps', async () => {
    repo.samples = [
      mkSample('steps', 8000, '2026-06-01T00:00:00.000Z'),
      mkSample('steps', 10000, '2026-06-02T00:00:00.000Z'),
    ];
    const summary = await useCase.execute('uid', 7);
    expect(summary.totalSteps).toBe(18000);
  });

  it('pega weight mais recente', async () => {
    repo.samples = [
      mkSample('weight', 75, '2026-05-25T00:00:00.000Z'),
      mkSample('weight', 73, '2026-06-02T00:00:00.000Z'), // mais recente
      mkSample('weight', 74, '2026-05-30T00:00:00.000Z'),
    ];
    const summary = await useCase.execute('uid', 7);
    expect(summary.latestWeight).toBe(73);
  });

  it('windowDays é refletido na resposta', async () => {
    const summary = await useCase.execute('uid', 14);
    expect(summary.windowDays).toBe(14);
  });
});
