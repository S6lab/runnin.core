import { BiometricSampleType } from '../domain/biometric-sample.entity';
import { BiometricSampleRepository } from '../domain/biometric-sample.repository';

export interface BiometricSummary {
  windowDays: number;
  from: string;
  to: string;
  // Métricas agregadas (null se sem dados)
  avgRestingBpm: number | null;
  maxBpm: number | null;
  avgSleepHours: number | null;
  totalSteps: number | null;
  avgHrv: number | null;
  latestWeight: number | null;
  sampleCount: number;
}

/**
 * Computa rollup de N dias por demanda (não usa cache/precompute por enquanto).
 * Custo Firestore: 1 query por user, até 500 docs (limit no repo).
 */
export class GetSummaryUseCase {
  constructor(private readonly repo: BiometricSampleRepository) {}

  async execute(userId: string, windowDays: number = 7): Promise<BiometricSummary> {
    const to = new Date();
    const from = new Date(to.getTime() - windowDays * 24 * 3600 * 1000);

    const samples = await this.repo.findByDateRange(userId, undefined, from, to);

    const byType = (type: BiometricSampleType) => samples.filter((s) => s.type === type);
    const avg = (xs: number[]) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : null);
    const sum = (xs: number[]) => (xs.length ? xs.reduce((a, b) => a + b, 0) : null);

    const restingBpms = byType('resting_bpm').map((s) => s.value);
    const maxBpms = byType('max_bpm').map((s) => s.value);
    const sleepHours = byType('sleep_hours').map((s) => s.value);
    const steps = byType('steps').map((s) => s.value);
    const hrvs = byType('hrv').map((s) => s.value);
    const weights = byType('weight')
      .sort((a, b) => b.recordedAt.localeCompare(a.recordedAt))
      .map((s) => s.value);

    return {
      windowDays,
      from: from.toISOString(),
      to: to.toISOString(),
      avgRestingBpm: avg(restingBpms),
      maxBpm: maxBpms.length ? Math.max(...maxBpms) : null,
      avgSleepHours: avg(sleepHours),
      totalSteps: sum(steps),
      avgHrv: avg(hrvs),
      latestWeight: weights[0] ?? null,
      sampleCount: samples.length,
    };
  }
}
