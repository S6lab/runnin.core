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
    // SLEEP: Apple Watch em iOS 16+ reporta apenas DEEP/REM/LIGHT (sleep_hours
    // pode vir vazio mesmo com user permitindo Sono). Total real é
    // DEEP + REM + LIGHT. Mantemos compat com sleep_hours (apps mais
    // antigos / Android Health Connect) somando ele também — recordedAt
    // diferentes evitam dupla-contagem na prática.
    const sleepHoursRaw = byType('sleep_hours').map((s) => s.value);
    const sleepDeep = byType('sleep_deep').map((s) => s.value);
    const sleepRem = byType('sleep_rem').map((s) => s.value);
    const sleepLight = byType('sleep_light').map((s) => s.value);
    // Sleep médio por DIA, não por sample. Agrupa por dia (YYYY-MM-DD) e
    // soma as horas dentro do dia; depois tira média entre os dias.
    const sleepByDay = new Map<string, number>();
    const addSample = (s: { recordedAt: string; value: number }) => {
      const day = s.recordedAt.substring(0, 10);
      sleepByDay.set(day, (sleepByDay.get(day) ?? 0) + s.value);
    };
    byType('sleep_hours').forEach(addSample);
    byType('sleep_deep').forEach(addSample);
    byType('sleep_rem').forEach(addSample);
    byType('sleep_light').forEach(addSample);
    const sleepDaily = Array.from(sleepByDay.values());
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
      avgSleepHours: avg(sleepDaily),
      totalSteps: sum(steps),
      avgHrv: avg(hrvs),
      latestWeight: weights[0] ?? null,
      sampleCount: samples.length,
    };
  }
}
