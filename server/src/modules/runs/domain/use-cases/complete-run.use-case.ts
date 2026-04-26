import { z } from 'zod';
import { RunRepository } from '../run.repository';
import { Run } from '../run.entity';
import { NotFoundError } from '@shared/errors/app-error';

export const CompleteRunSchema = z.object({
  distanceM: z.number().positive(),
  durationS: z.number().positive(),
  avgBpm: z.number().optional(),
  maxBpm: z.number().optional(),
});

export type CompleteRunInput = z.infer<typeof CompleteRunSchema>;

function formatPace(distanceM: number, durationS: number): string {
  if (distanceM === 0) return '0:00';
  const paceSecPerKm = (durationS / distanceM) * 1000;
  const min = Math.floor(paceSecPerKm / 60);
  const sec = Math.round(paceSecPerKm % 60);
  return `${min}:${sec.toString().padStart(2, '0')}`;
}

function calcXp(distanceM: number, durationS: number): number {
  const km = distanceM / 1000;
  const minutes = durationS / 60;
  return Math.round(km * 10 + minutes * 0.5);
}

export class CompleteRunUseCase {
  constructor(private readonly runRepo: RunRepository) {}

  async execute(runId: string, userId: string, input: CompleteRunInput): Promise<Run> {
    const run = await this.runRepo.findById(runId, userId);
    if (!run) throw new NotFoundError('Run');

    const updates: Partial<Run> = {
      status: 'completed',
      distanceM: input.distanceM,
      durationS: input.durationS,
      avgPace: formatPace(input.distanceM, input.durationS),
      avgBpm: input.avgBpm,
      maxBpm: input.maxBpm,
      xpEarned: calcXp(input.distanceM, input.durationS),
      completedAt: new Date().toISOString(),
    };

    await this.runRepo.update(runId, userId, updates);
    return { ...run, ...updates };
  }
}
