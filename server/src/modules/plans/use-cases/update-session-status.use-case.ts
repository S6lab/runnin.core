import { z } from 'zod';
import { PlanRepository } from '../domain/plan.repository';
import { SessionStatus } from '../domain/plan.entity';
import { NotFoundError } from '@shared/errors/app-error';

export const UpdateSessionStatusSchema = z.object({
  status: z.enum(['completed', 'skipped', 'rescheduled']),
  rescheduledTo: z.number().int().min(1).max(7).optional(), // Required if status is 'rescheduled'
});

export type UpdateSessionStatusInput = z.infer<typeof UpdateSessionStatusSchema>;

export class UpdateSessionStatusUseCase {
  constructor(private repo: PlanRepository) {}

  async execute(
    userId: string,
    planId: string,
    sessionId: string,
    input: UpdateSessionStatusInput,
  ): Promise<void> {
    // Validate rescheduledTo is provided when status is 'rescheduled'
    if (input.status === 'rescheduled' && !input.rescheduledTo) {
      throw new Error('rescheduledTo is required when status is "rescheduled"');
    }

    // Fetch the plan
    const plan = await this.repo.findById(planId, userId);
    if (!plan) {
      throw new NotFoundError('Plan not found');
    }

    // Find the session
    let sessionFound = false;
    const updatedWeeks = plan.weeks.map(week => ({
      ...week,
      sessions: week.sessions.map(session => {
        if (session.id === sessionId) {
          sessionFound = true;
          return {
            ...session,
            status: input.status as SessionStatus,
            completedAt: input.status === 'completed' ? new Date().toISOString() : undefined,
            rescheduledTo: input.rescheduledTo,
          };
        }
        return session;
      }),
    }));

    if (!sessionFound) {
      throw new NotFoundError('Session not found in plan');
    }

    // Update the plan with modified weeks
    await this.repo.update(planId, userId, {
      weeks: updatedWeeks,
      updatedAt: new Date().toISOString(),
    });
  }
}
