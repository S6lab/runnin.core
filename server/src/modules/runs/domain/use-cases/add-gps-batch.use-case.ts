import { z } from 'zod';
import { RunRepository } from '../run.repository';
import { NotFoundError } from '@shared/errors/app-error';

export const GpsPointSchema = z.object({
  lat: z.number(),
  lng: z.number(),
  ts: z.number(),
  accuracy: z.number(),
  pace: z.number().optional(),
  bpm: z.number().optional(),
});

export const AddGpsBatchSchema = z.object({
  points: z.array(GpsPointSchema).min(1).max(100),
});

export type AddGpsBatchInput = z.infer<typeof AddGpsBatchSchema>;

export class AddGpsBatchUseCase {
  constructor(private readonly runRepo: RunRepository) {}

  async execute(runId: string, userId: string, input: AddGpsBatchInput): Promise<{ accepted: number }> {
    const run = await this.runRepo.findById(runId, userId);
    if (!run) throw new NotFoundError('Run');

    await this.runRepo.addGpsBatch(runId, userId, input.points);
    return { accepted: input.points.length };
  }
}
