import { z } from 'zod';
import { v4 as uuidv4 } from 'uuid';
import { RunRepository } from '../run.repository';
import { Run } from '../run.entity';

export const CreateRunSchema = z.object({
  type: z.string().min(1),
  targetPace: z.string().optional(),
  targetDistance: z.string().optional(),
  planSessionId: z.string().optional(),
  environment: z.enum(['outdoor', 'indoor']).optional(),
  /** Corrida de AVALIAÇÃO: alvo em km escolhido pelo user. Presença deste
   *  campo marca a run como assessment — complete-run mede pace/distância
   *  e persiste como capacidade MEDIDA no profile. */
  assessmentTargetKm: z.number().positive().max(42).optional(),
});

export type CreateRunInput = z.infer<typeof CreateRunSchema>;

export class CreateRunUseCase {
  constructor(private readonly runRepo: RunRepository) {}

  async execute(userId: string, input: CreateRunInput): Promise<Run> {
    const run: Run = {
      id: uuidv4(),
      userId,
      status: 'active',
      type: input.type,
      targetPace: input.targetPace,
      targetDistance: input.targetDistance,
      planSessionId: input.planSessionId,
      environment: input.environment,
      assessmentTargetKm: input.assessmentTargetKm,
      distanceM: 0,
      durationS: 0,
      createdAt: new Date().toISOString(),
    };

    await this.runRepo.create(run);
    return run;
  }
}
