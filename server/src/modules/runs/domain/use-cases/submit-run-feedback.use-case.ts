import { z } from 'zod';
import { RunRepository } from '@modules/runs/domain/run.repository';
import { Run } from '@modules/runs/domain/run.entity';
import {
  CheckpointInput,
  CheckpointInputType,
} from '@modules/plans/domain/plan-checkpoint.entity';
import { AppError, NotFoundError } from '@shared/errors/app-error';

const INPUT_TYPES: CheckpointInputType[] = [
  'load_up',
  'load_down',
  'pain',
  'schedule_conflict',
  'low_energy',
  'sleep_bad',
  'great_week',
  'other',
];

const FeedbackInputSchema = z.object({
  type: z.enum(INPUT_TYPES as [CheckpointInputType, ...CheckpointInputType[]]),
  note: z.string().max(280).optional(),
});

export const SubmitRunFeedbackSchema = z.object({
  inputs: z.array(FeedbackInputSchema).max(8),
});

export type SubmitRunFeedbackInput = z.infer<typeof SubmitRunFeedbackSchema>;

export class RunNotCompletedError extends AppError {
  constructor() {
    super('Feedback só pode ser enviado depois que a corrida termina.', 409, 'RUN_NOT_COMPLETED');
  }
}

/**
 * Persiste o feedback subjetivo do user (chips + note) na própria run, logo
 * após a corrida. Substitui o fluxo de checkpoint "solto" — agora o coach
 * lê o feedback agregado das runs da semana no cron de domingo.
 *
 * Idempotente: re-submissão sobrescreve o feedback anterior (UX da ReportPage
 * pode permitir editar enquanto a tela estiver aberta).
 */
export class SubmitRunFeedbackUseCase {
  constructor(private readonly runRepo: RunRepository) {}

  async execute(
    runId: string,
    userId: string,
    input: SubmitRunFeedbackInput,
  ): Promise<Run> {
    const run = await this.runRepo.findById(runId, userId);
    if (!run) throw new NotFoundError('Run');
    if (run.status !== 'completed') throw new RunNotCompletedError();

    const userFeedback: CheckpointInput[] = dedupe(input.inputs);
    const feedbackAt = new Date().toISOString();
    await this.runRepo.update(runId, userId, { userFeedback, feedbackAt });
    return { ...run, userFeedback, feedbackAt };
  }
}

function dedupe(inputs: CheckpointInput[]): CheckpointInput[] {
  const seen = new Set<string>();
  return inputs.filter((i) => {
    const k = `${i.type}|${i.note ?? ''}`;
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
}
