import { z } from 'zod';
import { BenchmarkRepository } from '@modules/benchmark/domain/benchmark.repository';
import { RunRepository } from '@modules/runs/domain/run.repository';
import { FirestoreRunRepository } from '@modules/runs/infra/firestore-run.repository';

const BenchmarkParamsSchema = z.object({
  level: z.string(),
  runType: z.string(),
  distance: z.string(),
});

export type BenchmarkParams = z.infer<typeof BenchmarkParamsSchema>;

export class GetBenchmarkUseCase {
  private readonly runRepo: RunRepository;

  constructor(private readonly benchmarkRepo: BenchmarkRepository) {
    this.runRepo = new FirestoreRunRepository();
  }

  async execute(userId: string, params: BenchmarkParams): Promise<unknown> {
    const parsed = BenchmarkParamsSchema.safeParse(params);
    if (!parsed.success) {
      throw new Error(`Invalid params: ${parsed.error.message}`);
    }

    const { level, runType, distance } = parsed.data;
    const aggregate = await this.benchmarkRepo.findAggregate(level, runType, distance);

    if (!aggregate || aggregate.cohortSize === 0) {
      return {
        userPercentile: 0,
        userValues: {},
        cohortValues: {},
        cohortSize: 0,
      };
    }

    const userValues = await this.calculateUserValues(userId);
    const cohortValues = this.calculateCohortValues(aggregate);

    const userPercentile = this.calculatePercentile(userValues, cohortValues, aggregate.cohortSize);

    return {
      userPercentile,
      userValues,
      cohortValues,
      cohortSize: aggregate.cohortSize,
    };
  }

  private async calculateUserValues(userId: string): Promise<{ pace?: string; weeklyDistance?: string; consistency?: number; avgBpm?: number }> {
    try {
      const { runs } = await this.runRepo.findByUser(userId, 20);
      const completed = runs.filter((r) => r.status === 'completed' && r.completedAt);

      if (completed.length === 0) return {};

      const oneWeekAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;
      const weekRuns = completed.filter((r) => new Date(r.completedAt!).getTime() > oneWeekAgo);
      const weekDistanceM = weekRuns.reduce((sum, r) => sum + (r.distanceM || 0), 0);

      const paceMins = completed
        .map((r) => this.parsePaceToMinutes(r.avgPace))
        .filter((p): p is number => p !== undefined);
      const avgPace = paceMins.length > 0 ? paceMins.reduce((a, b) => a + b, 0) / paceMins.length : undefined;

      const bpms = completed.map((r) => r.avgBpm).filter((b): b is number => b !== undefined);
      const avgBpm = bpms.length > 0 ? Math.round(bpms.reduce((a, b) => a + b, 0) / bpms.length) : undefined;

      // Consistency = % of weeks in last 4 weeks that had at least 1 run
      const fourWeeksAgo = Date.now() - 28 * 24 * 60 * 60 * 1000;
      const recentRuns = completed.filter((r) => new Date(r.completedAt!).getTime() > fourWeeksAgo);
      const activeWeeks = new Set(recentRuns.map((r) => {
        const d = new Date(r.completedAt!);
        return `${d.getFullYear()}-W${Math.ceil(d.getDate() / 7)}`;
      }));
      const consistency = Math.round((activeWeeks.size / 4) * 100);

      return {
        pace: this.formatPace(avgPace),
        weeklyDistance: weekDistanceM > 0 ? `${Math.round(weekDistanceM / 1000)}km` : undefined,
        consistency,
        avgBpm,
      };
    } catch {
      return {};
    }
  }

  private parsePaceToMinutes(pace?: string): number | undefined {
    if (!pace) return undefined;
    const parts = pace.split(':');
    if (parts.length !== 2) return undefined;
    const min = parseInt(parts[0], 10);
    const sec = parseInt(parts[1], 10);
    if (isNaN(min) || isNaN(sec)) return undefined;
    return min + sec / 60;
  }

  private calculateCohortValues(aggregate: any): unknown {
    const paceAvg = aggregate.paceAvgs.length > 0
      ? aggregate.paceAvgs.reduce((a: number, b: number) => a + b, 0) / aggregate.paceAvgs.length
      : undefined;

    const bpmAvg = aggregate.bpmAvgs.length > 0
      ? aggregate.bpmAvgs.reduce((a: number, b: number) => a + b, 0) / aggregate.bpmAvgs.length
      : undefined;

    const distAvg = aggregate.distAvgs.length > 0
      ? aggregate.distAvgs.reduce((a: number, b: number) => a + b, 0) / aggregate.distAvgs.length
      : undefined;

    const consistencyAvg = aggregate.consistencyAvgs.length > 0
      ? aggregate.consistencyAvgs.reduce((a: number, b: number) => a + b, 0) / aggregate.consistencyAvgs.length
      : undefined;

    return {
      pace: this.formatPace(paceAvg),
      weeklyDistance: distAvg ? `${Math.round(distAvg)}km` : undefined,
      consistency: Math.round(consistencyAvg || 0),
      avgBpm: Math.round(bpmAvg || 0),
    };
  }

  private calculatePercentile(userValues: any, cohortValues: any, cohortSize: number): number {
    if (!cohortValues || cohortSize === 0) return 0;

    let userScore = 0;
    let totalMetrics = 0;

    if (userValues.pace && cohortValues.pace) {
      const userPace = this.parsePaceToSeconds(userValues.pace);
      const cohortPace = this.parsePaceToSeconds(cohortValues.pace);
      if (userPace !== undefined && cohortPace !== undefined) {
        userScore += userPace < cohortPace ? 1 : 0;
        totalMetrics++;
      }
    }

    if (userValues.weeklyDistance && cohortValues.weeklyDistance) {
      const userDist = parseInt(userValues.weeklyDistance.replace('km', ''), 10);
      const cohortDist = parseInt(cohortValues.weeklyDistance.replace('km', ''), 10);
      if (!isNaN(userDist) && !isNaN(cohortDist)) {
        userScore += userDist > cohortDist ? 1 : 0;
        totalMetrics++;
      }
    }

    if (userValues.consistency !== undefined && cohortValues.consistency !== undefined) {
      userScore += userValues.consistency > cohortValues.consistency ? 1 : 0;
      totalMetrics++;
    }

    if (userValues.avgBpm !== undefined && cohortValues.avgBpm !== undefined) {
      const userBpm = userValues.avgBpm;
      const cohortBpm = cohortValues.avgBpm;
      if (!isNaN(userBpm) && !isNaN(cohortBpm)) {
        userScore += userBpm < cohortBpm ? 1 : 0;
        totalMetrics++;
      }
    }

    if (totalMetrics === 0) return 0;

    const percentage = userScore / totalMetrics;
    return Math.round(percentage * 100);
  }

  private parsePaceToSeconds(paceStr: string): number | undefined {
    try {
      const [min, sec] = paceStr.split(':').map(Number);
      if (min === undefined || sec === undefined) return undefined;
      return min * 60 + sec;
    } catch (_) {
      return undefined;
    }
  }

  private formatPace(value?: number): string | undefined {
    if (!value) return undefined;
    const min = Math.floor(value);
    const sec = Math.round((value - min) * 60);
    return `${min}:${sec.toString().padStart(2, '0')}`;
  }
}
